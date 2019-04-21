//
//  ViewController.swift
//  CoreDataStack
//
//  Created by NSSimpleApps on 28/02/2019.
//  Copyright © 2019 NSSimpleApps. All rights reserved.
//

import UIKit
import CoreData

class Cell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ParentsListController: UITableViewController {
    private var shouldShowActivity = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let now = Date()
        DataManager.shared.coreDataManager.viewContext { (viewContext) in
            do {
                let fetchRequest: NSFetchRequest<Parent> = Parent.fetchRequest()
                fetchRequest.fetchBatchSize = 20
                let sortDescriptor = NSSortDescriptor(keyPath: \Parent.orderIndex, ascending: true)
                fetchRequest.sortDescriptors = [sortDescriptor]
                
                let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: viewContext,
                                                                           sectionNameKeyPath: Parent.nameKeyValue,
                                                                           cacheName: "Parents")
                try aFetchedResultsController.performFetch()
                
                DispatchQueue.main.async {
                    self.shouldShowActivity = false
                    self.tableView.register(Cell.self, forCellReuseIdentifier: "Cell")
                    
                    self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Insert", style: .plain,
                                                                            target: self, action: #selector(self.insertObject(_:)))
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Delete", style: .plain,
                                                                             target: self, action: #selector(self.deleteAll(_:)))
                    self.fetchedResultsController = aFetchedResultsController
                    aFetchedResultsController.delegate = self
                    self.tableView.reloadData()
                    print("Loading time:", Date().timeIntervalSince(now))
                }
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    @objc func deleteAll(_ sender: UIBarButtonItem) {
        sender.isEnabled = false
        
        DataManager.shared.coreDataManager.performBackgroundTask { (context) in
            do {
                let request: NSFetchRequest<Parent> = Parent.fetchRequest()
                request.includesPropertyValues = false
                
                let objects = try context.fetch(request)
                for object in objects {
                    context.delete(object)
                }
                try context.save()
            } catch {
                print(error)
            }
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
        }
    }
    
    
    @objc func insertObject(_ sender: UIBarButtonItem) {
        sender.isEnabled = false
        
        DataManager.shared.coreDataManager.performBackgroundTask { (context) in
            do {
                let request: NSFetchRequest<Parent> = Parent.fetchRequest()
                let count = try context.count(for: request)
                
                let parent = Parent(context: context)
                parent.nameValue = "Parent \(count)"
                parent.orderIndex = Int64(count)
                
                try context.save()
            } catch {
                print(error)
            }
            DispatchQueue.main.async {
                sender.isEnabled = true
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        let count = self.fetchedResultsController?.sections?.count ?? 0
        if count == 0 {
            if self.shouldShowActivity {
                let activity = UIActivityIndicatorView(style: .gray)
                activity.startAnimating()
                tableView.backgroundView = activity
            } else {
                let label = UILabel()
                label.textAlignment = .center
                label.text = "No parents"
                
                tableView.backgroundView = label
            }
        } else {
            tableView.backgroundView = nil
        }
        return count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sectionInfo = self.fetchedResultsController?.sections?[section] {
            return sectionInfo.numberOfObjects
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let fetchedResultsController = self.fetchedResultsController else {
            return UITableViewCell()
        }
        let parent = fetchedResultsController.object(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = parent.nameValue
        cell.detailTextLabel?.text = String(parent.childs?.count ?? 0)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return self.fetchedResultsController != nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let parent = self.fetchedResultsController?.object(at: indexPath) {
            let childsListController = ChildsListController(objectId: parent.objectID)

            self.navigationController?.pushViewController(childsListController, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, let fetchedResultsController = self.fetchedResultsController {
            tableView.isUserInteractionEnabled = false
            
            let objectID = fetchedResultsController.object(at: indexPath).objectID
            
            DataManager.shared.coreDataManager.performBackgroundTask { (context) in
                let object = context.object(with: objectID)
                context.delete(object)
                do {
                    try context.save()
                } catch {
                    print(error)
                }
                DispatchQueue.main.async {
                    tableView.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    private var fetchedResultsController: NSFetchedResultsController<Parent>?
}

extension ParentsListController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.tableView.insertSections([sectionIndex], with: .fade)
        case .delete:
            self.tableView.deleteSections([sectionIndex], with: .fade)
        default:
            return
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        let tableView = self.tableView!
        
        switch (type, indexPath, newIndexPath) {
        case (.insert, _, let new?):
            tableView.insertRows(at: [new], with: .fade)
        case (.delete, let ip?, _):
            tableView.deleteRows(at: [ip], with: .fade)
        case (.update, let ip?, _):
            tableView.reloadRows(at: [ip], with: .automatic)
        case (.move, let ip?, let new?):
            if ip == new {
                tableView.reloadRows(at: [ip], with: .fade)
            } else {
                tableView.reloadRows(at: [ip, new], with: .fade)
            }
        default:
            return
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }
}
