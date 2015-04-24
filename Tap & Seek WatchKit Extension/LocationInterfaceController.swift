//
//  LocationInterfaceController.swift
//  TapAndSeek
//
//  Created by Cameron Little on 4/23/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import WatchKit
import Foundation
import CoreLocation

class LocationInterfaceController: WKInterfaceController {
    @IBOutlet weak var map: WKInterfaceMap!
    @IBOutlet weak var nameLabel: WKInterfaceLabel!
    @IBOutlet weak var imageBox: WKInterfaceImage!
    @IBOutlet weak var elevationLabel: WKInterfaceLabel!
    @IBOutlet weak var goButton: WKInterfaceButton!

    var location: WatchLocationInformation?

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)

        // Configure interface objects here.
        if let location = context as? WatchLocationInformation {
            self.location = location
            setTitle(location.name)
            
            map.addAnnotation(CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), withPinColor: .Red)
            map.addAnnotation(CLLocationCoordinate2D(latitude: location.foundLatitude, longitude: location.foundLongitude), withPinColor: .Green)

            var southWest = CLLocationCoordinate2D()
            var northEast = CLLocationCoordinate2D()
            southWest.latitude = min(location.latitude, location.foundLatitude)
            southWest.longitude = min(location.longitude, location.foundLongitude)
            northEast.latitude = max(location.latitude, location.foundLatitude)
            northEast.longitude = max(location.longitude, location.foundLongitude)

            let locSouthWest = CLLocation(latitude: southWest.latitude, longitude: southWest.longitude)
            let locNorthEast = CLLocation(latitude: northEast.latitude, longitude: northEast.longitude)

            let dist = locSouthWest.distanceFromLocation(locNorthEast) * 2

            var region = MKCoordinateRegion()
            region.center.latitude = (southWest.latitude + northEast.latitude) / 2
            region.center.longitude = (southWest.longitude + northEast.longitude) / 2
            region.span.latitudeDelta = dist / 111319.5
            region.span.longitudeDelta = 0

            map.setRegion(region)

            nameLabel.setText(location.name)
            elevationLabel.setText("\(location.elevation)m")
            imageBox.setImage(UIImage(data: location.image))
        } else {
            popController()
        }
    }

    @IBAction func goButtonTap() {
        let coord = CLLocationCoordinate2D(latitude: location!.latitude, longitude: location!.longitude)
        let placemark = MKPlacemark(coordinate: coord, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)

        let launchOptions: [NSObject : AnyObject] = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]

        if !MKMapItem.openMapsWithItems([mapItem], launchOptions: launchOptions) {
            println("Failed to open map")
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
    
}

