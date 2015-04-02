//
//  MapViewController.swift
//  SeeThere
//
//  Created by Cameron Little on 2/1/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import AddressBookUI

struct Information {
    var location: CLLocation
    var pitch: Double
    var direction: Double
}

class MapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet var mapView: MKMapView!
    @IBOutlet weak var nameText: UITextView!
    @IBOutlet weak var descText: UITextView!
    @IBOutlet weak var imageView: UIImageView!

    var appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    var locationInformation: LocationInformation?
    var foundLocation: CLLocation {
        return locationInformation!.foundLocation!.location
    }

    var locPin = MKPointAnnotation()
    var youPin = MKPointAnnotation()

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        mapView.addAnnotation(locPin)
        mapView.addAnnotation(youPin)
    }

    func switchMapStyle(animated: Bool) {
        if mapView.mapType == MKMapType.Standard {
            setMapSat(animated)
        } else {
            setMapStandard(animated)
        }
    }

    func setMapSat(animated: Bool) {
        mapView.mapType = MKMapType.Hybrid
        setMapRegion(animated)
    }

    func setMapStandard(animated: Bool) {
        mapView.mapType = MKMapType.Standard
        if mapView.pitchEnabled {
            var eye: CLLocationCoordinate2D = locationInformation!.location.coordinate
            var alt: CLLocationDistance = locationInformation!.location.altitude
            var camera = MKMapCamera(lookingAtCenterCoordinate: foundLocation.coordinate, fromEyeCoordinate: eye, eyeAltitude: 1)
            mapView.camera = camera
        } else {
            setMapRegion(animated)
        }
    }

    func setMapRegion(animated: Bool) {
        let aLoc = locationInformation!.location.coordinate
        let bLoc = foundLocation.coordinate

        let sw = CLLocation(latitude: min(aLoc.latitude, bLoc.latitude), longitude: min(aLoc.longitude, bLoc.longitude))
        let ne = CLLocation(latitude: max(aLoc.latitude, bLoc.latitude), longitude: max(aLoc.longitude, bLoc.longitude))
        let dist = sw.distanceFromLocation(ne)

        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (sw.coordinate.latitude + ne.coordinate.latitude) / 2, longitude: (sw.coordinate.longitude + ne.coordinate.longitude) / 2), span: MKCoordinateSpan(latitudeDelta: dist / 111319.5, longitudeDelta: 0))

        mapView.setRegion(mapView.regionThatFits(region), animated: animated)
    }

    func actionLocation() {
        let geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(foundLocation, completionHandler: { (placemarks: [AnyObject]!, error: NSError!) in
            let coord = self.foundLocation.coordinate
            let lat = self.foundLocation.coordinate.latitude
            let lng = self.foundLocation.coordinate.longitude
            let elv = self.foundLocation.altitude

            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)

            // Apple Maps Action
            let appleMapsAction = UIAlertAction(title: NSLocalizedString("OpenMaps", comment: "open in apple maps app"), style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                let placemark = MKPlacemark(coordinate: coord, addressDictionary: nil)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = "Location Spotted \(self.foundLocation.timestamp)"
                mapItem.openInMapsWithLaunchOptions(nil)
            })
            actionSheet.addAction(appleMapsAction)

            // Google Maps action
            if UIApplication.sharedApplication().canOpenURL(NSURL(string: "comgooglemaps://")!) {
                let action = UIAlertAction(title: NSLocalizedString("OpenGoogleMaps", comment: "open in google maps app"), style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                    let str = "comgooglemaps://?q=\(lat),\(lng)&center=\(lat),\(lng)"
                    UIApplication.sharedApplication().openURL(NSURL(string: str)!)
                })
                actionSheet.addAction(action)
            }

            // Share url action
            let shareLinkAction = UIAlertAction(title: NSLocalizedString("ShareLink", comment: "open in google maps app"), style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                let locURL = NSURL(string: "http://maps.apple.com/?ll=\(lat),\(lng)")!
                let sheet = UIActivityViewController(activityItems: [locURL], applicationActivities: nil)
                sheet.excludedActivityTypes =
                    [UIActivityTypePostToWeibo,
                        UIActivityTypePrint,
                        UIActivityTypeSaveToCameraRoll,
                        UIActivityTypeAddToReadingList,
                        UIActivityTypePostToFlickr,
                        UIActivityTypePostToVimeo,
                        UIActivityTypePostToTencentWeibo]
                self.presentViewController(sheet, animated: true, completion: nil)
            })
            actionSheet.addAction(shareLinkAction)

            // Share text action
            let shareTextAction = UIAlertAction(title: NSLocalizedString("ShareLatLng", comment: "share latitude and longitude"), style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                let locString = "\(lat), \(lng)"
                let sheet = UIActivityViewController(activityItems: [locString], applicationActivities: nil)
                sheet.excludedActivityTypes =
                    [UIActivityTypePostToWeibo,
                        UIActivityTypePrint,
                        UIActivityTypeSaveToCameraRoll,
                        UIActivityTypeAddToReadingList,
                        UIActivityTypePostToFlickr,
                        UIActivityTypePostToVimeo,
                        UIActivityTypePostToTencentWeibo]
                self.presentViewController(sheet, animated: true, completion: nil)
            })
            actionSheet.addAction(shareTextAction)

            // Share GPX action
            let shareGPXAction = UIAlertAction(title: NSLocalizedString("GPXFile", comment: "a gpx file"), style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                let actpro = GPXFileActivityProvider(location: self.foundLocation)
                let share = self.toolbarItems![1] as! UIBarButtonItem
                let activity = OpenInActivity(url: actpro.fileURL, barItem: share)

                let sheet = UIActivityViewController(activityItems: [actpro], applicationActivities: [activity])
                sheet.excludedActivityTypes =
                    [UIActivityTypePostToWeibo,
                        UIActivityTypePrint,
                        UIActivityTypeSaveToCameraRoll,
                        UIActivityTypeAddToReadingList,
                        UIActivityTypePostToFlickr,
                        UIActivityTypePostToVimeo,
                        UIActivityTypePostToTencentWeibo]
                self.presentViewController(sheet, animated: true, completion: nil)
            })
            actionSheet.addAction(shareGPXAction)

            // Share VCard action
            let shareVCardAction = UIAlertAction(title: NSLocalizedString("VCard", comment: "a v card with contact information"), style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                // Generate VCard with location as home
                let rootPlacemark = placemarks[0] as! CLPlacemark
                let evolvedPlacemark = MKPlacemark(placemark: rootPlacemark)

                let persona: ABRecord = ABPersonCreate().takeUnretainedValue()
                ABRecordSetValue(persona, kABPersonFirstNameProperty, evolvedPlacemark.name, nil)
                let multiHome: ABMutableMultiValue = ABMultiValueCreateMutable(UInt32(kABMultiDictionaryPropertyType)).takeUnretainedValue()

                let didAddHome = ABMultiValueAddValueAndLabel(multiHome, evolvedPlacemark.addressDictionary, kABHomeLabel, nil)

                if didAddHome {
                    ABRecordSetValue(persona, kABPersonAddressProperty, multiHome, nil)
                    let vcards = ABPersonCreateVCardRepresentationWithPeople([persona]).takeUnretainedValue()
                    let vcardString = NSString(data: vcards, encoding: NSASCIIStringEncoding)
                    let documentsDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! NSString
                    var error: NSError?
                    let filePath = documentsDirectory.stringByAppendingPathComponent("pin.loc.vcf")
                    vcardString?.writeToFile(filePath, atomically: true, encoding: NSUTF8StringEncoding, error: &error)
                    let fileURL = NSURL(fileURLWithPath: filePath)!

                    let sheet = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    sheet.excludedActivityTypes =
                        [UIActivityTypePostToWeibo,
                            UIActivityTypePrint,
                            UIActivityTypeSaveToCameraRoll,
                            UIActivityTypeAddToReadingList,
                            UIActivityTypePostToFlickr,
                            UIActivityTypePostToVimeo,
                            UIActivityTypePostToTencentWeibo]
                    self.presentViewController(sheet, animated: true, completion: nil)
                } else {
                    let alert = UIAlertController(title: NSLocalizedString("Failed", comment: "failed"), message: NSLocalizedString("FailedVCardMessage", comment: "failed to generate vcard"), preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "okay"), style: UIAlertActionStyle.Cancel, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                }
            })
            actionSheet.addAction(shareVCardAction)

            // Cancel action
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "cancel"), style: UIAlertActionStyle.Cancel, handler: nil)
            actionSheet.addAction(cancelAction)
            
            self.presentViewController(actionSheet, animated: true, completion: nil)
        })
    }

    override func viewWillAppear(animated: Bool) {
        if locationInformation?.foundLocation == nil {
            alertError(NSLocalizedString("FailedMapLocation", comment: "error, no location on map")) {
                //TODO: go back to camera view controller.
            }
        } else {
            locPin.setCoordinate(foundLocation.coordinate)
            locPin.title = locationInformation!.name

            youPin.setCoordinate(locationInformation!.location.coordinate)
            youPin.title = "Your position"

            mapView.mapType = MKMapType.Hybrid
            setMapRegion(false)
        }
    }

    override func viewDidDisappear(animated: Bool) {
        locationInformation = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

