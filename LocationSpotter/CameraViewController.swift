//
//  ViewController.swift
//  LocationSpotter
//
//  Created by Cameron Little on 1/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation
import CoreMotion
import Social
import MapKit
import AddressBookUI

class CameraViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet var mainView: UIView!
    @IBOutlet var tapGestureRecognizer: UITapGestureRecognizer!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var pitchText: UITextField!
    @IBOutlet weak var headingText: UITextField!
    @IBOutlet weak var locationText: UITextField!
    
    private let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    private var spottedLocation: CLLocationCoordinate2D?

    func sayReady() {
        if ready {
            textField.text = "Ready!"
        } else {
            textField.text = "Getting Ready"
        }
    }

    var appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate

    private var locationReady = false
    private var headingReady = false
    private var pitchReady = true // I think this should essentially be always available.
    var ready: Bool {
        get {
            return locationReady// && headingReady && pitchReady
        }
    }

    var observers: [AnyObject] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("locationUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            if let loc = self.appDelegate.currentLocation {
                self.locationText.text = "(\(loc.coordinate.latitude), \(loc.coordinate.longitude)) at \(loc.altitude)"
            }
            self.locationReady = true
            self.sayReady()
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("headingUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.headingText.text = "\(self.appDelegate.currentDirection?)"
            self.headingReady = true
            self.sayReady()
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("pitchUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.pitchText.text = "\(self.appDelegate.currentPitch?)"
            self.pitchReady = true
            self.sayReady()
        }))

        // set up video capturing
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetHigh
        var error: NSError?
        let input: AVCaptureDeviceInput? = AVCaptureDeviceInput.deviceInputWithDevice(device, error: &error) as? AVCaptureDeviceInput
        if (input == nil) {
            println("Couldn't set up camera")
        } else {
            // add video into main view
            session.addInput(input!)
            
            var previewLayer = AVCaptureVideoPreviewLayer.layerWithSession(session) as AVCaptureVideoPreviewLayer
            previewLayer.frame = mainView.bounds
            
            mainView.layer.addSublayer(previewLayer)
        }

        self.sayReady()
    }

    /*override func viewDidUnload() {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }*/
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        return ready
    }

    lazy var mapViewController: MapViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let m = storyboard.instantiateViewControllerWithIdentifier("mapViewControllerID") as MapViewController
        let done = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: "closeMap")
        let share = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self, action: "actionLocation")
        let flex = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: self, action: nil)
        m.navigationItem.leftBarButtonItem = done
        m.toolbarItems = [flex, share, flex]
        return m
    }()
    lazy var mapViewNavController: UINavigationController = {
        let n = UINavigationController(rootViewController: self.mapViewController)
        n.toolbarHidden = false
        return n
    }()

    func closeMap() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    func actionLocation() {
        let actLocation = CLLocation(latitude: spottedLocation!.latitude, longitude: spottedLocation!.longitude)

        let geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(actLocation
            , completionHandler: { (placemarks: [AnyObject]!, error: NSError!) in
            let locString = "\(self.spottedLocation!.latitude), \(self.spottedLocation!.longitude)"
            let locURL = NSURL(string: "http://maps.apple.com/?q=&ll=\(self.spottedLocation!.latitude),\(self.spottedLocation!.longitude)")!
            let location = CLLocation(latitude: self.spottedLocation!.latitude, longitude: self.spottedLocation!.longitude)

            var items = [locURL, locString]

            let rootPlacemark = placemarks[0] as CLPlacemark
            let evolvedPlacemark = MKPlacemark(placemark: rootPlacemark)

            let persona: ABRecord = ABPersonCreate().takeUnretainedValue()
            ABRecordSetValue(persona, kABPersonFirstNameProperty, evolvedPlacemark.name, nil)
            let multiHome: ABMutableMultiValue = ABMultiValueCreateMutable(UInt32(kABMultiDictionaryPropertyType)).takeUnretainedValue()

            let didAddHome = ABMultiValueAddValueAndLabel(multiHome, evolvedPlacemark.addressDictionary, kABHomeLabel, nil)

            if didAddHome {
                ABRecordSetValue(persona, kABPersonAddressProperty, multiHome, nil)
                let vcards = ABPersonCreateVCardRepresentationWithPeople([persona]).takeUnretainedValue()
                let vcardString = NSString(data: vcards, encoding: NSASCIIStringEncoding)
                let documentsDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
                var error: NSError?
                let filePath = documentsDirectory.stringByAppendingPathComponent("pin.loc.vcf")
                vcardString?.writeToFile(filePath, atomically: true, encoding: NSUTF8StringEncoding, error: &error)
                let fileURL = NSURL(fileURLWithPath: filePath)!
                items.append(fileURL)
            }

            let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
            sheet.excludedActivityTypes =
                [UIActivityTypePostToWeibo,
                UIActivityTypePrint,
                UIActivityTypeSaveToCameraRoll,
                UIActivityTypeAddToReadingList,
                UIActivityTypePostToFlickr,
                UIActivityTypePostToVimeo,
                UIActivityTypePostToTencentWeibo]

            self.mapViewController.presentViewController(sheet, animated: true, completion: nil)
        })
    }

    @IBAction func tapGestureAction(sender: UITapGestureRecognizer) {
        if ready {
            var tapLocation = sender.locationInView(self.view)

            //spottedLocation = walkOutFrom(appDelegate.currentLocation!,
            //                           getDirection(Double(tapLocation.y)),
            //                           getPitch(Double(tapLocation.x)))

            spottedLocation = CLLocationCoordinate2D(latitude: 48.82277, longitude: -122.489905)

            mapViewController.locationSpotted = spottedLocation
            mapViewNavController.title = "Spotted Location"

            self.presentViewController(mapViewNavController, animated: true, completion: nil)
        }
    }
    
    private var screenRect = UIScreen.mainScreen().bounds
    lazy private var width: Double = {
        return Double(self.screenRect.size.width)
    }()
    lazy private var height: Double = {
        return Double(self.screenRect.size.height)
    }()
    lazy private var fovHorizontal: Double = {
        if self.device == nil {
            self.textField.text = "No camera found"
            return 0
        }
        return Double(self.device.activeFormat.videoFieldOfView)
    }()
    lazy private var fovVertical: Double = {
        return (self.width / self.height) * self.fovHorizontal
    }()

    func getPitch(pointY: Double) -> Double {
        let a = (height / 2) / tan(radians(fovVertical / 2))

        let offset = pointY - height/2
        let offsetAngle = atan2(offset, a)

        /*let pitch = { () -> Double in
            switch UIDevice.currentDevice().orientation {
            case UIDeviceOrientation.Portrait:
                return self.appDelegate.motionManager.deviceMotion.attitude.pitch
            case UIDeviceOrientation.PortraitUpsideDown:
                return -self.appDelegate.motionManager.deviceMotion.attitude.pitch
            case UIDeviceOrientation.LandscapeLeft:
                return self.appDelegate.motionManager.deviceMotion.attitude.roll
            case UIDeviceOrientation.LandscapeRight:
                return -self.appDelegate.motionManager.deviceMotion.attitude.roll
            default:
                fatalError("Unknown device orientation")
            }
        }()*/

        return appDelegate.currentPitch! + offsetAngle
    }

    func getDirection(pointX: Double) -> CLLocationDirection {
        let a = (width / 2) / tan(radians(fovHorizontal / 2))

        let offset = pointX - width/2
        let offsetAngle = atan2(offset, a)

        return appDelegate.currentDirection! + offsetAngle
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}