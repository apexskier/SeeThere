//
//  LocationInformation.swift
//  TapAndSeek
//
//  Created by Cameron Little on 3/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation

@objc(LocationInformation)
class LocationInformation: NSManagedObject {

    @NSManaged var elevation: Double
    @NSManaged var heading: Double
    @NSManaged var image: NSData
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var pitch: Double
    @NSManaged var foundLocation: FoundLocation?
    @NSManaged var dateTime: NSDate
    @NSManaged var name: String

    var location: CLLocation {
        get {
            return CLLocation(coordinate: CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude), altitude: self.elevation, horizontalAccuracy: 0, verticalAccuracy: 0, course: self.heading, speed: 0, timestamp: NSDate())
        }
        set {
            self.latitude = newValue.coordinate.latitude
            self.longitude = newValue.coordinate.longitude

            if newValue.altitude > 0 {
                self.elevation = newValue.altitude
            }

            if newValue.course > 0 {
                self.heading = newValue.course
            }
        }
    }

}
