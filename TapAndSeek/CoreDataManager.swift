/*
Copyright (C) 2014 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:

Singleton controller to manage the main Core Data stack for the application. It vends a persistent store coordinator, and for convenience the managed object model and URL for the persistent store and application documents directory.

*/

import CoreData

class CoreDataManager {
    // MARK: Types

    private struct Constants {
        static let applicationDocumentsDirectoryName = NSBundle.mainBundle().bundleIdentifier!
        static let mainStoreFileName = "TapAndSeek.datastore"
        static let errorDomain = "CoreDataManager"
    }

    class var sharedManager: CoreDataManager {
        struct Singleton {
            static let coreDataManager = CoreDataManager()
        }

        return Singleton.coreDataManager
    }

    /// The managed object model for the application.
    lazy var managedObjectModel: NSManagedObjectModel = {
        // This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("Model", withExtension: "momd")!

        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    /// Primary persistent store coordinator for the application.
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
        if let url = self.storeURL {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)

            let options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]

            var error: NSError?

            let persistentStore = persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: options, error: &error)
            if persistentStore == nil {
                fatalError("Error adding persistent store: \(error)")
            }

            return persistentStoreCoordinator
        }

        return nil
        }()

    /// The directory the application uses to store the Core Data store file.
    lazy var applicationDocumentsDirectory: NSURL? = {
        let fileManager = NSFileManager.defaultManager()
        let urls = fileManager.URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)
        var applicationSupportDirectory = urls[urls.count - 1] as! NSURL
        applicationSupportDirectory = applicationSupportDirectory.URLByAppendingPathComponent(Constants.applicationDocumentsDirectoryName)

        var error: NSError?

        if let properties = applicationSupportDirectory.resourceValuesForKeys([NSURLIsDirectoryKey], error: &error) {
            if let isDirectory = properties[NSURLIsDirectoryKey] as? NSNumber {
                if !isDirectory.boolValue {
                    let description = NSLocalizedString("Could not access the application data folder.", comment: "Failed to initialize applicationSupportDirectory")

                    let reason = NSLocalizedString("Found a file in its place.", comment: "Failed to initialize applicationSupportDirectory")

                    let userInfo = [
                        NSLocalizedDescriptionKey: description,
                        NSLocalizedFailureReasonErrorKey: reason
                    ]

                    error = NSError(domain: Constants.errorDomain, code: 101, userInfo: userInfo)

                    fatalError("Could not access the application data folder. \(error)")
                }
            }
        }
        else {
            if error != nil && error!.code == NSFileReadNoSuchFileError {
                if !fileManager.createDirectoryAtPath(applicationSupportDirectory.path!, withIntermediateDirectories: true, attributes: nil, error: &error) {
                    fatalError("Could not create the application data folder. \(error)")
                }
            }
        }

        return applicationSupportDirectory
        }()

    /// URL for the main Core Data store file.
    lazy var storeURL: NSURL? = {
        if let add = self.applicationDocumentsDirectory {
            return add.URLByAppendingPathComponent(Constants.mainStoreFileName)
        }

        return nil
        }()
}
