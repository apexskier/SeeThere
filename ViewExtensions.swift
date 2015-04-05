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
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "okay"), style: .Cancel, handler: nil))
        self.presentViewController(alert, animated: true, completion: handler)
    }

    func askToSave(moc: NSManagedObjectContext, message: String, object: LocationInformation, completion: (() -> Void)) {
        var mes: String
        if message == "" {
            mes = NSLocalizedString("SaveQMessage", comment: "asking for save")
        } else {
            mes = NSLocalizedString("SaveQMessageFailed", comment: "asking for save after failure") + message
        }

        let alert = UIAlertController(title: NSLocalizedString("SaveQTitle", comment: "ask to save"), message: mes, preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler { (textField: UITextField!) -> Void in
            textField.placeholder = "Name this location"
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: "okay"), style: .Default, handler: { (action: UIAlertAction!) -> Void in
            let textField = alert.textFields![0] as! UITextField

            object.name = textField.text
            var error: NSError?
            if !moc.save(&error) {
                self.alertError("Error saving: \(error)") {}
            }
            completion()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("No", comment: "no"), style: UIAlertActionStyle.Cancel, handler: { (action: UIAlertAction!) -> Void in
            moc.reset()
            completion()
        }))

        self.presentViewController(alert, animated: true) {}
    }
}