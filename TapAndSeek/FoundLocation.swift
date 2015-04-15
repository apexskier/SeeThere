//
//  FoundLocation.swift
//  TapAndSeek
//
//  Created by Cameron Little on 3/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation

@objc(FoundLocation)
class FoundLocation: NSManagedObject {

    @NSManaged var elevation: Double
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var information: LocationInformation

    var location: CLLocation {
        get {
            return CLLocation(coordinate: CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude), altitude: self.elevation, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: NSDate())
        }
        set {
            self.latitude = newValue.coordinate.latitude
            self.longitude = newValue.coordinate.longitude

            if newValue.altitude > 0 {
                self.elevation = newValue.altitude
            }
        }
    }

}
