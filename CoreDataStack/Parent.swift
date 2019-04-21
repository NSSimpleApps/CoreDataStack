//
//  Parent.swift
//  CoreDataStack
//
//  Created by NSSimpleApps on 28/02/2019.
//  Copyright © 2019 NSSimpleApps. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Parent)
public class Parent: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Parent> {
        return NSFetchRequest<Parent>(entityName: "Parent")
    }
    
    @NSManaged public var orderIndex: Int64
    @NSManaged public var childs: NSSet?
    
    #if CORE_DATA_VERSION_0
    #else
        @NSManaged public var email: String?
    #endif
    
    
    #if CORE_DATA_VERSION_0 || CORE_DATA_VERSION_1
        @NSManaged private var title1: String?
    #else
        @NSManaged private var title2: String?
    #endif
    
    public var nameValue: String? {
        set {
            #if CORE_DATA_VERSION_0 || CORE_DATA_VERSION_1
                self.title1 = newValue
            #else
                self.title2 = newValue
            #endif
        }
        get {
            #if CORE_DATA_VERSION_0 || CORE_DATA_VERSION_1
                return self.title1
            #else
                return self.title2
            #endif
        }
    }
    
    public static var nameKeyValue: String {
        #if CORE_DATA_VERSION_0 || CORE_DATA_VERSION_1
            return "title1"
        #else
            return "title2"
        #endif
    }
}
