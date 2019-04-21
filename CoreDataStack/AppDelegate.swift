//
//  AppDelegate.swift
//  CoreDataStack
//
//  Created by NSSimpleApps on 28/02/2019.
//  Copyright © 2019 NSSimpleApps. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = UINavigationController(rootViewController: ParentsListController(style: .grouped))
        self.window?.makeKeyAndVisible()
        return true
    }
}

