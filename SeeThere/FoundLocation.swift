//
//  FoundLocation.swift
//  SeeThere
//
//  Created by Cameron Little on 3/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation
import CoreData

class FoundLocation: NSManagedObject {

    @NSManaged var elevation: Double
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var information: LocationInformation

}
