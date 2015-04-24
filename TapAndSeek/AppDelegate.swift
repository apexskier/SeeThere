
//  AppDelegate.swift
//  TapAndSeek
//
//  Created by Cameron Little on 1/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate {

    var window: UIWindow?

    var currentLocation: CLLocation?
    var currentDirection: CLLocationDirection?
    var currentPitch: Double?
    var currentYaw: Double?
    var currentRoll: Double?

    let locationManager = CLLocationManager()
    let motionManager = CMMotionManager()

    /// Managed object context for the view controller (which is bound to the persistent store coordinator for the application).
    lazy var managedObjectContext: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        moc.persistentStoreCoordinator = CoreDataManager.sharedManager.persistentStoreCoordinator
        return moc
    }()

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let mostRecentLocation = locations.last as? CLLocation
        if mostRecentLocation == nil {
            return
        }
        currentLocation = mostRecentLocation
        NSNotificationCenter.defaultCenter().postNotificationName("locationUpdated", object: currentLocation)
    }

    func locationManager(manager: CLLocationManager!, didUpdateHeading newHeading: CLHeading!) {
        if newHeading.headingAccuracy < 0 {
            return
        }
        currentDirection = (newHeading.trueHeading > 0) ? newHeading.trueHeading : newHeading.magneticHeading
        NSNotificationCenter.defaultCenter().postNotificationName("headingUpdated", object: currentLocation)
    }


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        locationManager.delegate = self

        let new = NSEntityDescription.insertNewObjectForEntityForName("LocationInformation", inManagedObjectContext: self.managedObjectContext) as! LocationInformation
        new.location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 47.1234, longitude: -122.1234), altitude: 60, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: NSDate())
        new.heading = 0.1234
        new.pitch = 0.5678
        new.dateTime = NSDate()
        new.image = UIImageJPEGRepresentation(UIImage(named: "testimage.png"), 90)
        new.name = "Test Location"

        let found = NSEntityDescription.insertNewObjectForEntityForName("FoundLocation", inManagedObjectContext: self.managedObjectContext) as! FoundLocation
        found.location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 47.5678, longitude: -122.5678), altitude: 70, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: NSDate())
        new.foundLocation = found

        var error: NSError?
        managedObjectContext.save(&error)

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        motionManager.stopDeviceMotionUpdates()
        saveWatchData()
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        println(CoreDataManager.sharedManager.applicationDocumentsDirectory)

        // start getting location and heading
        locationManager.requestWhenInUseAuthorization()

        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        } else {
            let alert = UIAlertController(title:  NSLocalizedString("Error", comment: "failed, heading not available"), message: NSLocalizedString("FailedHeading", comment: "failed, heading not available"), preferredStyle: UIAlertControllerStyle.Alert)
            UIApplication.sharedApplication().keyWindow?.rootViewController!.presentViewController(alert, animated: true, completion: nil)
        }

        // start getting motion
        motionManager.deviceMotionUpdateInterval = 0.02; // 50 Hz
        if motionManager.deviceMotionAvailable {
            motionManager.startDeviceMotionUpdatesUsingReferenceFrame(CMAttitudeReferenceFrame.XArbitraryCorrectedZVertical, toQueue: NSOperationQueue.mainQueue(), withHandler: { (data: CMDeviceMotion!, error: NSError!) -> Void in
                let q = data.attitude.quaternion

                self.currentPitch = { () -> Double in
                    let num: Double = (2 * q.x * q.w) - (2 * q.y * q.z)
                    let den: Double = 1 - (2 * q.x * q.x) - (2 * q.z * q.z)
                    return abs(atan2(num, den)) - M_PI_2
                }()

                self.currentRoll = { () -> Double in
                    let num: Double = (2 * q.y * q.w) - (2 * q.x * q.z)
                    let den: Double = 1 - (2 * q.x * q.x) - (2 * q.z * q.z)
                    return atan2(num, den)
                }()

                self.currentYaw = { () -> Double in
                    return asin((2 * q.x * q.y) + (2 * q.z * q.w))
                }()

                /*
                self.currentPitch = { () -> Double? in
                    switch UIDevice.currentDevice().orientation {
                    case UIDeviceOrientation.Portrait:
                        return data.attitude.pitch - M_PI/2
                    case UIDeviceOrientation.PortraitUpsideDown:
                        return -data.attitude.pitch
                    case UIDeviceOrientation.LandscapeLeft:
                        return data.attitude.roll
                    case UIDeviceOrientation.LandscapeRight:
                        return -data.attitude.roll
                    default:
                        return nil
                    }
                }()*/
                NSNotificationCenter.defaultCenter().postNotificationName("pitchUpdated", object: self.currentPitch)
            })
        }
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground.
        saveWatchData()
    }

    func saveWatchData() {
        let fileManager = NSFileManager.defaultManager()
        if let groupUrl = fileManager.containerURLForSecurityApplicationGroupIdentifier("group.camlittle.see-there") {
            var error: NSError?
            let request = NSFetchRequest(entityName: "LocationInformation")
            let fetched = self.managedObjectContext.executeFetchRequest(request, error: &error) as? [LocationInformation]
            if error != nil {
                //DEBUG
                fatalError("problem fetching data")
            }
            if let sources = fetched {
                var transformed = [WatchLocationInformation]()
                for location in sources {
                    if let fl = location.foundLocation {
                        let imageData = UIImageJPEGRepresentation(squareImageToSize(UIImage(data: location.image)!, 96), 90)

                        transformed.append(WatchLocationInformation(
                            elevation: location.elevation,
                            heading: location.heading,
                            image: imageData,
                            latitude: location.latitude,
                            longitude: location.longitude,
                            pitch: location.pitch,
                            dateTime: location.dateTime,
                            name: location.name,
                            foundElevation: fl.elevation,
                            foundLatitude: fl.latitude,
                            foundLongitude: fl.longitude))
                    }
                }
                if transformed.count > 0 {
                    NSKeyedUnarchiver.setClass(WatchLocationInformation.self, forClassName: "WatchLocationInformation")
                    NSKeyedArchiver.setClassName("WatchLocationInformation", forClass: WatchLocationInformation.self)
                    if !NSKeyedArchiver.archiveRootObject(transformed, toFile: groupUrl.URLByAppendingPathComponent("locations.data").path!) {
                        println("Failed to encode and write data.")
                    }
                }
            }
        } else {
            println("Failed to save data")
        }
    }


    /// Mark: WatchKit
    func application(application: UIApplication, handleWatchKitExtensionRequest userInfo: [NSObject : AnyObject]?, reply: (([NSObject : AnyObject]!) -> Void)!) {
        println("watchkit talked to me")
    }
}

func squareImageToSize(image: UIImage, newSize: CGFloat) -> UIImage {
    let squareSize = CGSize(width: newSize, height: newSize)

    var ratio: CGFloat
    var delta: CGFloat
    var offset: CGPoint

    //figure out if the picture is landscape or portrait, then
    //calculate scale factor and offset
    if (image.size.width > image.size.height) {
        ratio = newSize / image.size.width;
        delta = (ratio * image.size.width - ratio * image.size.height);
        offset = CGPointMake(delta/2, 0);
    } else {
        ratio = newSize / image.size.height;
        delta = (ratio * image.size.height - ratio * image.size.width);
        offset = CGPointMake(0, delta/2);
    }
    let clipRect = CGRect(x: -offset.x, y: -offset.y,
        width: (ratio * image.size.width) + delta,
        height: (ratio * image.size.height) + delta)

    if UIScreen.mainScreen().respondsToSelector("scale") {
        UIGraphicsBeginImageContextWithOptions(squareSize, true, 0)
    } else {
        // NOTE: This one will be faster, since it's less data.
        UIGraphicsBeginImageContext(squareSize)
    }

    UIRectClip(clipRect)
    image.drawInRect(clipRect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return newImage
}