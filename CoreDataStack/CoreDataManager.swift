//
//  CoreDataManager.swift
//  CoreDataStack
//
//  Created by NSSimpleApps on 28/02/2019.
//  Copyright © 2019 NSSimpleApps. All rights reserved.
//

import Foundation
import CoreData

public protocol CoreDataManagerConfigurator: AnyObject {
    static var name: String { get }
    static var currentModel: NSManagedObjectModel { get }
    static func migrationManager(forOldVersion oldVersion: Int) throws -> (NSMigrationManager, NSMappingModel)
}

public class CoreDataManager {
    private let persistentContainer: NSPersistentContainer
    private var isAvailable = false
    private let condition = NSCondition()
    
    public init(configurator: CoreDataManagerConfigurator.Type) {
        let now = Date()
        let container = NSPersistentContainer(name: configurator.name, managedObjectModel: configurator.currentModel)
        self.persistentContainer = container
        let condition = self.condition
        
        if Thread.isMainThread {
            DispatchQueue.global().async {
                self.initStore(container: container, configurator: configurator, condition: condition, now: now)
            }
        } else {
            self.initStore(container: container, configurator: configurator, condition: condition, now: now)
        }
    }
    
    private func initStore(container: NSPersistentContainer, configurator: CoreDataManagerConfigurator.Type,
                           condition: NSCondition, now: Date) {
        condition.lock()
        let name = container.name
        if case let persistentStoreDescriptions = container.persistentStoreDescriptions, persistentStoreDescriptions.isEmpty == false {
            self.isAvailable = false
            
            for persistentStoreDescription in persistentStoreDescriptions {
                persistentStoreDescription.shouldAddStoreAsynchronously = true
                Self.migrateOfNeeded(storeDescription: persistentStoreDescription, currentModel: container.managedObjectModel, configurator: configurator)
            }
            container.loadPersistentStores(completionHandler: { (storeDescription, error) in
                if let error = error {
                    print(error)
                }
                print("Initialization time \(name):", Date().timeIntervalSince(now))
                condition.lock()
                self.isAvailable = true
                condition.broadcast()
                condition.unlock()
            })
        } else {
            self.isAvailable = true
        }
        condition.unlock()
    }
    
    public static func setVersion(_ version: Int, forModel model: NSManagedObjectModel) {
        model.versionIdentifiers = [version]
    }
    public static func getVersion(fromModel model: NSManagedObjectModel) -> Int? {
        return model.versionIdentifiers.first as? Int
    }
    
    public var viewContext: NSManagedObjectContext {
        self.condition.lock()
        while self.isAvailable == false {
            self.condition.wait()
        }
        let viewContext = self.persistentContainer.viewContext
        if viewContext.automaticallyMergesChangesFromParent == false {
            viewContext.automaticallyMergesChangesFromParent = true
            viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        self.condition.unlock()
        return viewContext
    }
    
    public var newBackgroundContext: NSManagedObjectContext {
        self.condition.lock()
        while self.isAvailable == false {
            self.condition.wait()
        }
        let newBackgroundContext = self.persistentContainer.newBackgroundContext()
        newBackgroundContext.automaticallyMergesChangesFromParent = true
        newBackgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.condition.unlock()
        return newBackgroundContext
    }
    
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        self.condition.lock()
        while self.isAvailable == false {
            self.condition.wait()
        }
        self.isAvailable = false
        self.persistentContainer.performBackgroundTask { [weak self] (context) in
            guard let sSelf = self else { return }
            
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            block(context)
            sSelf.condition.lock()
            sSelf.isAvailable = true
            sSelf.condition.broadcast()
            sSelf.condition.unlock()
        }
        self.condition.unlock()
    }
    public func saveContext() {
        let context = self.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

private extension CoreDataManager {
    /// Версии базы:
    /// 0 - сущности ParentObject, ChildObject
    /// 1 - в ParentObject добавлено опциональное поле email: String? // легковесная миграция
    /// 2 - у ParentObject переименовано поле title1 в title2
    /// 3 - у всех Child увеличить rating на 1 // TODO
    static func migrateOfNeeded(storeDescription: NSPersistentStoreDescription, currentModel: NSManagedObjectModel, configurator: CoreDataManagerConfigurator.Type) {
        guard let sourceUrl = storeDescription.url else { return }
        guard let currentVersion = self.getVersion(fromModel: currentModel) else { return }
        
        let storeType = NSSQLiteStoreType
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: storeType, at: sourceUrl, options: nil)
            guard let versions = metadata[NSStoreModelVersionIdentifiersKey] as? [Int], let oldVersion = versions.first, oldVersion <= currentVersion else {
                try persistentStoreCoordinator.destroyPersistentStore(at: sourceUrl, ofType: storeType, options: nil)
                return
            }
            if oldVersion == currentVersion {
                return
            }
            let destinationURL = sourceUrl.appendingPathExtension("tmp")
            print(oldVersion, currentVersion)
            
            for version in oldVersion..<currentVersion {
                let (migrationManager, mappingModel) = try configurator.migrationManager(forOldVersion: version)
                print("MIGRATE FROM:", version)
                try migrationManager.migrateStore(from: sourceUrl, sourceType: storeType,
                                                  options: nil, with: mappingModel,
                                                  toDestinationURL: destinationURL, destinationType: storeType,
                                                  destinationOptions: nil)
                try persistentStoreCoordinator.replacePersistentStore(at: sourceUrl, destinationOptions: nil,
                                                                      withPersistentStoreFrom: destinationURL, sourceOptions: nil,
                                                                                                 ofType: storeType)
                try persistentStoreCoordinator.destroyPersistentStore(at: destinationURL, ofType: storeType, options: nil)
                try FileManager.default.removeItem(at: destinationURL)
            }
            
        } catch let catchedError as NSError {
            if catchedError.code != NSFileReadNoSuchFileError {
                print(#line, catchedError)
                do {
                    try persistentStoreCoordinator.destroyPersistentStore(at: sourceUrl, ofType: storeType, options: nil)
                } catch {
                    print(#line, error)
                    fatalError()
                }
            }
        }
    }
}
