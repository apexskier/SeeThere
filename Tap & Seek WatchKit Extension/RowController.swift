//
//  RowController.swift
//  SeeThere
//
//  Created by Cameron Little on 4/14/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import WatchKit

class RowController: NSObject {
    @IBOutlet weak var textLabel: WKInterfaceLabel!
    @IBOutlet weak var imageBox: WKInterfaceImage!

    // MARK: Methods

    func setText(text: String) {
        textLabel.setText(text)
    }

    func setImage(image: UIImage) {
        imageBox.setImage(image)
    }
}