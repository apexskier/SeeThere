//
//  Shared.swift
//  TapAndSeek
//
//  Created by Cameron Little on 4/14/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation

extension NSError {
    var usefulDescription: String {
        if let m = self.localizedFailureReason {
            return m
        } else if self.localizedDescription != "" {
            return self.localizedDescription
        }
        return self.domain
    }
}

class WatchLocationInformation: NSObject, NSCoding {
    var elevation: Double
    var heading: Double
    var image: NSData
    var latitude: Double
    var longitude: Double
    var pitch: Double
    var dateTime: NSDate
    var name: String

    var foundElevation: Double
    var foundLatitude: Double
    var foundLongitude: Double

    init(elevation: Double, heading: Double, image: NSData, latitude: Double, longitude: Double, pitch: Double, dateTime: NSDate, name: String, foundElevation: Double, foundLatitude: Double, foundLongitude: Double) {
        self.elevation = elevation
        self.heading = heading
        self.image = image
        self.latitude = latitude
        self.longitude = longitude
        self.pitch = pitch
        self.dateTime = dateTime
        self.name = name

        self.foundElevation = foundElevation
        self.foundLatitude = foundLatitude
        self.foundLongitude = foundLongitude
    }

    required init(coder aDecoder: NSCoder) {
        elevation = aDecoder.decodeDoubleForKey("elevation")
        heading = aDecoder.decodeDoubleForKey("heading")
        image = aDecoder.decodeObjectForKey("image") as! NSData
        latitude = aDecoder.decodeDoubleForKey("latitude")
        longitude = aDecoder.decodeDoubleForKey("longitude")
        pitch = aDecoder.decodeDoubleForKey("pitch")
        dateTime = aDecoder.decodeObjectForKey("dateTime") as! NSDate
        name = aDecoder.decodeObjectForKey("name") as! String

        foundElevation = aDecoder.decodeDoubleForKey("foundElevation")
        foundLatitude = aDecoder.decodeDoubleForKey("foundLatitude")
        foundLongitude = aDecoder.decodeDoubleForKey("foundLongitude")

        super.init()
    }

    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeDouble(elevation, forKey: "elevation")
        aCoder.encodeDouble(heading, forKey: "heading")
        aCoder.encodeObject(image, forKey: "image")
        aCoder.encodeDouble(latitude, forKey: "latitude")
        aCoder.encodeDouble(longitude, forKey: "longitude")
        aCoder.encodeDouble(pitch, forKey: "pitch")
        aCoder.encodeObject(dateTime, forKey: "dateTime")
        aCoder.encodeObject(name, forKey: "name")

        aCoder.encodeDouble(foundElevation, forKey: "foundElevation")
        aCoder.encodeDouble(foundLatitude, forKey: "foundLatitude")
        aCoder.encodeDouble(foundLongitude, forKey: "foundLongitude")
    }
}