//
//  GPX.swift
//  TapAndSeek
//
//  Created by Cameron Little on 2/3/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

class GPXFileActivityProvider: UIActivityItemProvider {
    let location: CLLocation

    lazy var fileURL: NSURL = {
        let gpxStr = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n<gpx xmlns=\"http://www.topografix.com/GPX/1/1\"\nxmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\nxsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd\"\nversion=\"1.1\"\ncreator=\"com.camlittle.locationspotter\">\n<wpt lat=\"\(self.location.coordinate.latitude)\" lon=\"\(self.location.coordinate.longitude)\">\n<ele>\(self.location.altitude)</ele>\n<time>\(self.location.timestamp)</time>\n</wpt>\n</gpx>"
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! NSString
        var error: NSError?
        let filePath = documentsDirectory.stringByAppendingPathComponent("location-\(self.location.timestamp.description).gpx")
        gpxStr.writeToFile(filePath, atomically: true, encoding: NSUTF8StringEncoding, error: &error)
        let fileURL = NSURL(fileURLWithPath: filePath)!

        return fileURL
    }()

    init(location: CLLocation) {
        self.location = location
        super.init()
    }

    override func activityViewControllerPlaceholderItem(activityViewController: UIActivityViewController) -> AnyObject {
        return fileURL
    }

    override func activityViewController(activityViewController: UIActivityViewController, itemForActivityType activityType: String) -> AnyObject? {
        return fileURL
    }

    override func activityViewController(activityViewController: UIActivityViewController, subjectForActivityType activityType: String?) -> String {
        return location.description
    }

    override func activityViewController(activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: String?) -> String {
        return "com.topografix.gpx"
    }
}