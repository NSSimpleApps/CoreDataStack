//
//  DataManager.swift
//  CoreDataStack
//
//  Created by NSSimpleApps on 12/04/2019.
//  Copyright © 2019 NSSimpleApps. All rights reserved.
//

import Foundation
import CoreData

public class DataManager {
    public static let shared = DataManager()
    public let coreDataManager: CoreDataManager
    
    private init() {
        self.coreDataManager = CoreDataManager(configurator: DataManager.self)
    }
}

extension DataManager: CoreDataManagerConfigurator {
    public static var name: String {
        return "Model"
    }
    
    public static var currentModel: NSManagedObjectModel {
        #if CORE_DATA_VERSION_0
        return self.model0()
        #elseif CORE_DATA_VERSION_1
        return self.model1()
        #elseif CORE_DATA_VERSION_2
        return self.model2()
        #elseif CORE_DATA_VERSION_3
        return self.model3()
        #else
        #error("No CORE_DATA_VERSION_N defined in Build Settings.")
        #endif
    }
    
    static func model0() -> NSManagedObjectModel {
        let childDescription = NSEntityDescription()
        childDescription.name = String(describing: Child.self)
        childDescription.managedObjectClassName = childDescription.name
        
        let parentDescription = NSEntityDescription()
        parentDescription.name = String(describing: Parent.self)
        parentDescription.managedObjectClassName = parentDescription.name
        
        let parentTitle1Attribute = NSAttributeDescription()
        parentTitle1Attribute.name = "title1"
        parentTitle1Attribute.renamingIdentifier = "rename-parent-title1-identifier"
        parentTitle1Attribute.attributeType = .stringAttributeType
        parentTitle1Attribute.isOptional = true
        
        let parentOrderIndexAttribute = NSAttributeDescription()
        parentOrderIndexAttribute.name = "orderIndex"
        parentOrderIndexAttribute.attributeType = .integer64AttributeType
        parentOrderIndexAttribute.isOptional = false
        
        let parentChildsRelationship = NSRelationshipDescription()
        parentChildsRelationship.name = "childs"
        parentChildsRelationship.isOptional = true
        parentChildsRelationship.destinationEntity = childDescription
        //parentChildsRelationship.inverseRelationship
        parentChildsRelationship.minCount = 0
        parentChildsRelationship.maxCount = 0
        parentChildsRelationship.deleteRule = .cascadeDeleteRule
        
        parentDescription.properties = [parentTitle1Attribute, parentOrderIndexAttribute, parentChildsRelationship]
        
        let childTextAttribute = NSAttributeDescription()
        childTextAttribute.name = "text"
        childTextAttribute.attributeType = .stringAttributeType
        childTextAttribute.isOptional = true
        
        let childRatingAttribute = NSAttributeDescription()
        childRatingAttribute.name = "rating"
        childRatingAttribute.attributeType = .integer64AttributeType
        childRatingAttribute.isOptional = false
        
        let childParentRelationship = NSRelationshipDescription()
        childParentRelationship.name = "parent"
        childParentRelationship.isOptional = true
        childParentRelationship.destinationEntity = parentDescription
        childParentRelationship.inverseRelationship = parentChildsRelationship
        childParentRelationship.minCount = 1
        childParentRelationship.maxCount = 1
        childParentRelationship.deleteRule = .nullifyDeleteRule
        
        childDescription.properties = [childTextAttribute, childRatingAttribute, childParentRelationship]
        
        parentChildsRelationship.inverseRelationship = childParentRelationship
        
        let model = NSManagedObjectModel()
        CoreDataManager.setVersion(0, forModel: model)
        model.entities = [parentDescription, childDescription]
        
        return model
    }
    
    static func model1() -> NSManagedObjectModel {
        let model = self.model0()
        CoreDataManager.setVersion(1, forModel: model)
        
        if let parentEntity = model.entities.first(where: { (entityDescription) -> Bool in
            entityDescription.name == String(describing: Parent.self)
        }) {
            let emailAttribute = NSAttributeDescription()
            emailAttribute.name = "email"
            emailAttribute.attributeType = .stringAttributeType
            emailAttribute.isOptional = true
            
            parentEntity.properties.append(emailAttribute)
        }
        return model
    }
    
    static func model2() -> NSManagedObjectModel {
        let model = self.model1()
        CoreDataManager.setVersion(2, forModel: model)
        
        if let parentEntity = model.entities.first(where: { (entityDescription) -> Bool in
            entityDescription.name == String(describing: Parent.self)
        }) {
            if let title1Description = parentEntity.properties.first(where: { (propertyDescription) -> Bool in
                propertyDescription.name == "title1"
            }) {
                title1Description.name = "title2"
            }
        }
        return model
    }
    static func model3() -> NSManagedObjectModel {
        let model = self.model2()
        CoreDataManager.setVersion(3, forModel: model)
        return model
    }
    
    public static func migrationManager(forOldVersion oldVersion: Int) throws -> (NSMigrationManager, NSMappingModel) {
        switch oldVersion {
        case 0:
            let model0 = self.model0()
            let model1 = self.model1()
            
            let mappingModel = try NSMappingModel.inferredMappingModel(forSourceModel: model0, destinationModel: model1)
            return (NSMigrationManager(sourceModel: model0, destinationModel: model1), mappingModel)
            
        case 1:
            let model1 = self.model1()
            let model2 = self.model2()
            let mappingModel = try NSMappingModel.inferredMappingModel(forSourceModel: model1, destinationModel: model2)
            
            return (NSMigrationManager(sourceModel: model1, destinationModel: model2), mappingModel)
        case 2:
            let model2 = self.model2()
            let model3 = self.model3()
            let mappingModel = try NSMappingModel.inferredMappingModel(forSourceModel: model2, destinationModel: model3)
            
            return (NSMigrationManager(sourceModel: model2, destinationModel: model3), mappingModel)
        default:
            fatalError()
        }
    }
}
