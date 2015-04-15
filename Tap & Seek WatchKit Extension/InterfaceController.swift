//
//  InterfaceController.swift
//  Tap & Seek WatchKit Extension
//
//  Created by Cameron Little on 4/14/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {
    @IBOutlet weak var table: WKInterfaceTable!
    @IBOutlet weak var errorGroup: WKInterfaceGroup!
    @IBOutlet weak var errorText: WKInterfaceLabel!

    override init() {
        super.init()
        errorGroup.setHidden(true)
    }

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.var request = [NSObject : AnyObject]()
        var request = [NSObject: AnyObject]()
        request["request"] = nil as AnyObject?
        WKInterfaceController.openParentApplication(request, reply: { (response: [NSObject : AnyObject]!, error: NSError!) -> Void in
            if error != nil {
                println(error.usefulDescription)
                self.errorGroup.setHidden(false)
                self.errorText.setText("Error")
            } else {
                let data = response["data"] as! [LocationInformation]
                self.table.setNumberOfRows(data.count, withRowType: "LocationWKRow")
                if data.count > 0 {
                    for i in 0...(data.count - 1) {
                        let row = self.table.rowControllerAtIndex(i) as! RowController
                        let loc = data[i]
                        row.setText(loc.name)
                        // this really should all be happening on the phone
                        if let image = UIImage(data: loc.image) {
                            // crop image to square
                            let size: CGFloat = CGFloat(min(image.size.width, image.size.height))
                            let x = (image.size.width - size) / 2.0
                            let y = (image.size.height - size) / 2.0

                            var cropRect: CGRect
                            // respect image orientation metadata
                            if (image.imageOrientation == .Left || image.imageOrientation == .Right) {
                                cropRect = CGRectMake(y, x, size, size)
                            } else {
                                cropRect = CGRectMake(x, y, size, size)
                            }

                            let imageRef = CGImageCreateWithImageInRect(image.CGImage, cropRect)

                            let square = UIImage(CGImage: imageRef)!
                            /*
                            // Figure out what our orientation is, and use that to form the rectangle
                            var newSize = CGSizeMake(128, 128)

                            // This is the rect that we've calculated out and this is what is actually used below
                            let rect = CGRectMake(0, 0, newSize.width, newSize.height)

                            // Actually do the resizing to the rect using the ImageContext stuff
                            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                            square.drawInRect(rect)
                            let resized = UIGraphicsGetImageFromCurrentImageContext()
                            UIGraphicsEndImageContext()
                            */
                            row.setImage(square)
                        }
                    }
                } else {
                    self.errorGroup.setHidden(false)
                    self.errorText.setText("No Locations")
                }
            }
        })
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}

