//
//  ViewExtensions.swift
//  SeeThere
//
//  Created by Cameron Little on 4/5/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreData

extension UIViewController {
    func alertError(message: String, handler: (() -> Void)) {
        let alert = UIAlertController(title: NSLocalizedString("Error", comment: "error message"), message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "okay"), style: UIAlertActionStyle.Cancel, handler: { (alert: UIAlertAction!) -> Void in
            handler()
        }))
        self.presentViewController(alert, animated: true) {}
    }
}