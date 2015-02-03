//
//  AppDelegate.swift
//  LocationSpotter
//
//  Created by Cameron Little on 1/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion

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

    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let mostRecentLocation = locations.last? as? CLLocation
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
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        // start getting location and heading
        locationManager.requestWhenInUseAuthorization()

        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        } else {
            println("Heading not available")
        }

        // start getting motion
        motionManager.deviceMotionUpdateInterval = 0.02; // 50 Hz
        if motionManager.deviceMotionAvailable {
            motionManager.startDeviceMotionUpdatesUsingReferenceFrame(CMAttitudeReferenceFrameXArbitraryCorrectedZVertical, toQueue: NSOperationQueue.mainQueue(), withHandler: { (data: CMDeviceMotion!, error: NSError!) -> Void in
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
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}

