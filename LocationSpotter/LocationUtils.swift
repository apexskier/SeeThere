//
//  LocationUtils.swift
//  LocationSpotter
//
//  Created by Cameron Little on 1/31/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation
import CoreLocation

private let HEIGHT_TOLERANCE: Double = -10
private let MAX_DISTANCE: Double = 20000
private let MIN_DISTANCE: Double = 20
private let DISTANCE_STEP: Double = 10
private let SLOPE_FACTOR: Double = 0.02

func radians(degrees: Double) -> Double {
    return degrees * (M_PI / 180)
}
func degrees(radians: Double) -> Double {
    return radians * (180 / M_PI)
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
        return nil
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

/* Get a list of locations, with altitude information between a start point and an end point.
 * Returned locations will be DISTANCE_STEP apart.
 *
 */
func getElevationPath(start: CLLocation, end: CLLocation) -> [CLLocation] {
    var ret: [CLLocation] = []
    
    let dist = start.distanceFromLocation(end)
    //let samples = min(Int(dist / DISTANCE_STEP), 512)
    let samples = Int(dist / DISTANCE_STEP)
    if samples > 512 {
        fatalError("getElevationPath start and end too far apart.")
    }
    
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

func newLocation(start: CLLocation, distance: CLLocationDistance, direction: CLLocationDirection) -> CLLocation {
    let startLat = radians(start.coordinate.latitude)
    let startLng = radians(start.coordinate.longitude)

    let dir = radians(direction)
    
    let sinStartLat = sin(startLat)
    let cosStartLat = cos(startLat)
    
    let earthRadius: CLLocationDistance = 6367.4447 * 1000 // meters
    let scaledDistance = distance / earthRadius
    
    let finLat = asin((sinStartLat * cos(scaledDistance)) + (cosStartLat * sin(scaledDistance) * cos(dir)))
    let finLng = startLng + atan2(sin(dir) * sin(scaledDistance) * cosStartLat, cos(scaledDistance) - sinStartLat * sin(finLat))
    
    return CLLocation(latitude: degrees(finLat), longitude: degrees(finLng))
}

func walkOutFrom(start: CLLocation, direction: CLLocationDirection, pitch: Double) -> CLLocation? {
    var distance = 1000.0
    var from = newLocation(start, MIN_DISTANCE, direction)
    println("starting at elevation \(start.altitude), with \(degrees(pitch))")
    let adjAlt = start.altitude + abs(start.verticalAccuracy) // should be positive, but I'll check anyway

    let flat = abs(pitch) < radians(10)

    var lastElev: CLLocationDistance = start.altitude

    func softenPitch(x: Double) -> Double {
        return (-1/x) + 1
    }

    while distance < MAX_DISTANCE {
        // fetch a set of points
        let to = newLocation(start, distance, direction)
        
        let pathLocs = getElevationPath(from, to)
        if pathLocs.count == 0 {
            fatalError("Failed to get elevation path")
            return nil
        }

        var gradient: Double = 0
        
        for loc in pathLocs {
            let softened = softenPitch(distance) * pitch
            let estimate = estimateElevation(loc.distanceFromLocation(start), adjAlt, softened)
            let actual = loc.altitude
            let diff = estimate - actual

            println("distance: \(loc.distanceFromLocation(start))")
            println(" estimate: \(estimate), actual: \(actual), diff: \(diff)")

            if flat { // don't calculate unless flat
                // NOTE: this slope's run may not be accurate
                gradient = (actual - lastElev) / DISTANCE_STEP
                println(" gradient: \(gradient)")
            }

            /* the flatness logic
             * Say you're looking at something in the distance, and you're on flat ground. 
             * There will be false intersections with the ground due to inaccuracies in
             * elevation data. So, when looking along a relatively flat line, we wait until
             * intersecting with a steepish slope, or something like a hill in the distance
             * that's obvious.
             */
            if ((!flat) || (flat && ((gradient > SLOPE_FACTOR) || (diff < (4*HEIGHT_TOLERANCE))))) &&
                (diff < HEIGHT_TOLERANCE) {
                return loc
            }

            lastElev = actual
        }
        
        distance += 1000
        from = to
    }
    return nil
}
