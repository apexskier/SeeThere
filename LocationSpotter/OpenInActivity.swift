//
//  OpenInActivity.swift
//  LocationSpotter
//
//  Created by Cameron Little on 2/3/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation
import UIKit

class OpenInActivity: UIActivity {
    let url: NSURL
    let barItem: UIBarButtonItem
    let docSheet: UIDocumentInteractionController

    init(url: NSURL, barItem: UIBarButtonItem) {
        self.url = url
        self.barItem = barItem
        self.docSheet = UIDocumentInteractionController(URL: url)
        super.init()
    }

    override func activityType() -> String? {
        return "openinapp"
    }

    override func activityTitle() -> String? {
        return "Open File in App"
    }

    override func activityImage() -> UIImage? {
        return UIImage(named: "open-in-icon.png")
    }

    override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        return true
    }

    override func performActivity() {
        docSheet.presentOpenInMenuFromBarButtonItem(barItem, animated: true)
    }
}