//
//  MapViewController.swift
//  LocationSpotter
//
//  Created by Cameron Little on 2/1/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet var mapView: MKMapView!

    var appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
    var locationSpotted: CLLocationCoordinate2D?

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
    }

    override func viewDidAppear(animated: Bool) {
        if mapView.pitchEnabled {
            let locPin = MKPointAnnotation()
            locPin.setCoordinate(locationSpotted!)
            locPin.title = "Spotted Location"
            mapView.addAnnotation(locPin)

            var eye: CLLocationCoordinate2D = appDelegate.currentLocation!.coordinate
            var alt: CLLocationDistance = appDelegate.currentLocation!.altitude
            var camera = MKMapCamera(lookingAtCenterCoordinate: locationSpotted!, fromEyeCoordinate: eye, eyeAltitude: alt)
            mapView.camera = camera
        }
    }

    @IBAction func shareTap(sender: AnyObject) {
        println("Share button tapped") // TODO
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

