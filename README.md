# CoreDataStack
A simple example of CoreData.

Требуется реализовать взаимодействие с CoreData.
1. Инициализацию и миграцию делать в фоне.
2. Модель и миграцию создавать только в коде.
3. Безопасное использование модельных классов.

```objc
public protocol CoreDataManagerConfigurator: AnyObject {
    static var name: String { get } // имя хранилища
    static var currentModel: NSManagedObjectModel { get } // текущая модель базы
    static func migrationManager(forOldVersion oldVersion: Int) throws -> (NSMigrationManager, NSMappingModel) // миграция от oldVersion
}

class CustomDataManager: CoreDataManagerConfigurator {
public static let shared = CustomDataManager()
public let coreDataManager: CoreDataManager
    
private init() {
    self.coreDataManager = CoreDataManager(configurator: CustomDataManager.self)
}
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
}
```


Использование:
```objc

CoreDataManager.setVersion(_ version: Int, forModel model: NSManagedObjectModel)
CoreDataManager.getVersion(fromModel model: NSManagedObjectModel) -> Int?
coreDataManager.viewContext({ viewContext in 
    
})
coreDataManager.performBackgroundTask({ viewContext in 

})
coreDataManager.saveContext()
```
