//
//  LocationUtils.swift
//  LocationSpotter
//
//  Created by Cameron Little on 1/31/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation
import CoreLocation
import CoreMotion

private let HEIGHT_TOLERANCE: Double = 10
private let MAX_DISTANCE: Double = 10000
private let MIN_DISTANCE: Double = 10
private let DISTANCE_STEP: Double = 10

func radians(degrees: Double) -> Double {
    return degrees * (M_PI / 180)
}
func degrees(radians: Double) -> Double {
    return radians * (180 / M_PI)
}

func calcPitch(quaternion: CMQuaternion) -> Double {
    let num: Double = (2 * quaternion.x * quaternion.w) - (2 * quaternion.y * quaternion.z)
    let den: Double = 1 - (2 * quaternion.x * quaternion.x) - (2 * quaternion.z * quaternion.z)
    
    return atan2(num, den)
}

func getElevationAt(coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
    if !CLLocationCoordinate2DIsValid(coordinate) {
        return nil
    }
    
    let reqURL = NSURL(string: "https://maps.googleapis.com/maps/api/elevation/json?key=\(googleAPIKey)&locations=\(coordinate.latitude),\(coordinate.longitude)")
    let request = NSURLRequest(URL: reqURL!)
    
    var error: NSError?
    var response: NSURLResponse?
    var data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &error)
    if error != nil {
        fatalError("\(error?.description)")
    }
    
    if (data!.length > 0) {
        var responseData: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions(0), error: &error)
        
        if responseData?.objectForKey("status") as String == "OK" {
            var results = responseData?.objectForKey("results")? as? [AnyObject]
            var elevation = results?[0].objectForKey("elevation") as Double
            return elevation
        } else if responseData?.objectForKey("status") as String == "OVER_QUERY_LIMIT" {
            return getElevationAt(coordinate)
        }
    }
    
    return nil
}

func getElevationPath(start: CLLocation, end: CLLocation) -> [CLLocation] {
    var ret: [CLLocation] = []
    
    let dist = start.distanceFromLocation(end)
    let samples = min(Int(dist / DISTANCE_STEP), 512)
    
    let reqURLString = "https://maps.googleapis.com/maps/api/elevation/json?key=\(googleAPIKey)&path=\(start.coordinate.latitude),\(start.coordinate.longitude)%7C\(end.coordinate.latitude),\(end.coordinate.longitude)&samples=\(samples)"
    let reqURL = NSURL(string: reqURLString)
    let request = NSURLRequest(URL: reqURL!)
    
    var error: NSError?
    var response: NSURLResponse?
    var data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &error)
    if error != nil {
        fatalError("\(error?.description)")
    }
    
    if (data!.length > 0) {
        var responseData: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions(0), error: &error)
        if responseData?.objectForKey("status") as String == "OK" {
            var results = responseData?.objectForKey("results")? as? [AnyObject]
            let now = NSDate()
            for loc in results! {
                let rawLocation: AnyObject? = loc.objectForKey("location")
                let coord = CLLocationCoordinate2D(latitude: rawLocation!.objectForKey("lat") as Double, longitude: rawLocation!.objectForKey("lng") as Double)
                let elev = loc.objectForKey("elevation") as Double
                let location = CLLocation(coordinate: coord, altitude: elev, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: now)
                ret.append(location)
            }
        } else if responseData?.objectForKey("status") as String == "OVER_QUERY_LIMIT" {
            return getElevationPath(start, end)
        }
    }
    
    return ret
}

func estimateElevation(distance: CLLocationDistance, startAltitude: CLLocationDistance, pitch: Double) -> CLLocationDistance {
    let heightDiff: CLLocationDistance = distance * tan(pitch)
    return startAltitude + heightDiff
}

func newLocation(start: CLLocationCoordinate2D, distance: CLLocationDistance, direction: CLLocationDirection) -> CLLocation {
    /*if !CLLocationCoordinate2DIsValid(start) {
    return nil
    }*/
    
    let startLat = radians(start.latitude)
    let startLng = radians(start.longitude)
    
    let sinStartLat = sin(startLat)
    let cosStartLat = cos(startLat)
    
    let earthRadius: CLLocationDistance = 6367.4447 * 1000 // meters
    let scaledDistance = distance / earthRadius
    
    let finLat = asin((sinStartLat * cos(scaledDistance)) + (cosStartLat * sin(scaledDistance) * cos(direction)))
    let finLng = startLng + atan2(sin(direction) * sin(scaledDistance) * cosStartLat, cos(scaledDistance) - sinStartLat * sin(finLat))
    
    return CLLocation(latitude: degrees(finLat), longitude: degrees(finLng))
}

func walkOutFrom(start: CLLocation, direction: CLLocationDirection, pitch: Double) -> CLLocationCoordinate2D? {
    var distance = 1000.0
    var from = start
    
    while (distance < MAX_DISTANCE) {
        // fetch a set of points
        let to = newLocation(start.coordinate, distance, direction)
        
        let pathLocs = getElevationPath(from, to)
        if pathLocs.count == 0 {
            fatalError("Failed to get elevation path")
        }
        
        for loc in pathLocs {
            println("\(loc.coordinate.latitude),\(loc.coordinate.longitude)")
            let estimate = estimateElevation(loc.distanceFromLocation(start), start.altitude, pitch)
            let actual = loc.altitude
            
            if (estimate < actual) {
                return loc.coordinate
            }
        }
        
        distance += 1000
        from = to
    }
    return nil
}
