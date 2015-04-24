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

    var data = [WatchLocationInformation]()

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        errorGroup.setHidden(true)

        // Configure interface objects here.var request = [NSObject : AnyObject]()
        let fileManager = NSFileManager.defaultManager()
        if let groupUrl = fileManager.containerURLForSecurityApplicationGroupIdentifier("group.camlittle.see-there") {
            let filename = groupUrl.URLByAppendingPathComponent("locations.data").path!
            NSKeyedUnarchiver.setClass(WatchLocationInformation.self, forClassName: "WatchLocationInformation")
            NSKeyedArchiver.setClassName("WatchLocationInformation", forClass: WatchLocationInformation.self)
            if let sources = NSKeyedUnarchiver.unarchiveObjectWithFile(filename) as? [WatchLocationInformation] {
                data = sources
                self.table.setNumberOfRows(sources.count, withRowType: "RowController")
                if sources.count > 0 {
                    for i in 0...(sources.count - 1) {
                        let row = self.table.rowControllerAtIndex(i) as! RowController
                        let loc = sources[i]
                        row.setText(loc.name)
                        if let image = UIImage(data: loc.image) {
                            row.setImage(image)
                        }
                        row.setDate(loc.dateTime)
                    }
                } else {
                    self.errorGroup.setHidden(false)
                    self.errorText.setText("No Locations Found")
                }
            } else {
                self.errorGroup.setHidden(false)
                self.errorText.setText("No Locations")
            }
        } else {
            println("Failed to open group")
            self.errorGroup.setHidden(false)
            self.errorText.setText("Error")
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    override func table(table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int) {
        pushControllerWithName("LocationView", context: data[rowIndex])
    }

}

