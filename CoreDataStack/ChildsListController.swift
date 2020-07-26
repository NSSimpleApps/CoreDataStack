//
//  ChildsListController.swift
//  CoreDataStack
//
//  Created by Sergey on 01/03/2019.
//  Copyright © 2019 NSSimpleApps. All rights reserved.
//

import UIKit
import CoreData

class ChildsListController: UITableViewController {
    let objectId: NSManagedObjectID
    
    init(objectId: NSManagedObjectID) {
        self.objectId = objectId.copy() as! NSManagedObjectID
        
        super.init(style: .grouped)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private var fetchedResultsController: NSFetchedResultsController<Child>?
    private var shouldShowActivity = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let now = Date()
        
        DispatchQueue.global().async {
            let viewContext = DataManager.shared.coreDataManager.viewContext
            
            do {
                guard let parent = try viewContext.existingObject(with: self.objectId) as? Parent else {
                    return
                }
                let name = parent.nameValue
                let fetchRequest: NSFetchRequest<Child> = Child.fetchRequest()
                fetchRequest.fetchBatchSize = 20
                let sortDescriptor = NSSortDescriptor(keyPath: \Child.rating, ascending: true)
                fetchRequest.sortDescriptors = [sortDescriptor]
                fetchRequest.predicate = NSPredicate(format: "parent = %@", parent)
                
                let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                           managedObjectContext: viewContext,
                                                                           sectionNameKeyPath: nil, cacheName: nil)
                try aFetchedResultsController.performFetch()
                
                DispatchQueue.main.async {
                    self.shouldShowActivity = false
                    self.tableView.register(Cell.self, forCellReuseIdentifier: "Cell")
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                                             target: self, action: #selector(self.addChildAction(_:)))
                    
                    self.fetchedResultsController = aFetchedResultsController
                    aFetchedResultsController.delegate = self
                    self.title = name
                    self.tableView.reloadData()
                    print("Loading time:", Date().timeIntervalSince(now))
                }
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    @objc private func addChildAction(_ sender: UIBarButtonItem) {
        let ac = UIAlertController(title: "Add child", message: nil, preferredStyle: .alert)
        ac.addTextField { (textField) in
            textField.placeholder = "Name"
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        ac.addAction(UIAlertAction(title: "Add", style: .default, handler: { (_) in
            sender.isEnabled = false
            
            let textFields = ac.textFields!
            let text = textFields[0].text!
            
            DataManager.shared.coreDataManager.performBackgroundTask({ (context) in
                do {
                    let child = Child(context: context)
                    child.text = text
                    child.rating = 0
                    
                    if let parent = try context.existingObject(with: self.objectId) as? Parent {
                        child.parent = parent
                    }
                    try context.save()
                } catch {
                    print(error)
                }
                DispatchQueue.main.async {
                    sender.isEnabled = true
                }
            })
        }))
        self.present(ac, animated: true, completion: nil)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.fetchedResultsController?.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = self.fetchedResultsController?.sections?[section].numberOfObjects ?? 0
        
        if count == 0 {
            let backgroundView: UIView
            if self.shouldShowActivity {
                let activityIndicatorView = UIActivityIndicatorView(style: .gray)
                activityIndicatorView.startAnimating()
                backgroundView = activityIndicatorView
            } else {
                let label = UILabel()
                label.textAlignment = .center
                label.text = "No childs"
                
                backgroundView = label
            }
            tableView.backgroundView = backgroundView
        } else {
            tableView.backgroundView = nil
        }
        
        return count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let child = self.fetchedResultsController?.object(at: indexPath) else {
            return UITableViewCell()
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = child.text
        cell.detailTextLabel?.text = String(child.rating)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let fetchedResultsController = self.fetchedResultsController {
            let child = fetchedResultsController.object(at: indexPath)
            child.rating += 1
            
            do {
                try fetchedResultsController.managedObjectContext.save()
            } catch {
                print(error)
            }
        }
    }
}
extension ChildsListController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
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
