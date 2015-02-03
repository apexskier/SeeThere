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
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var pitchText: UITextField!
    @IBOutlet weak var yawText: UITextField!
    @IBOutlet weak var rollText: UITextField!
    @IBOutlet weak var headingText: UITextField!

    private let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    private var spottedLocation: CLLocation?

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
    private var pitchReady = false
    private var cameraReady = false
    private var working = false
    var ready: Bool {
        get {
            let r = locationReady && headingReady && pitchReady && cameraReady && !working
            if r {
                activityIndicator.stopAnimating()
            }
            return r
        }
    }

    var observers: [AnyObject] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // set up video capturing
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetHigh
        var error: NSError?
        let input: AVCaptureDeviceInput? = AVCaptureDeviceInput.deviceInputWithDevice(device, error: &error) as? AVCaptureDeviceInput
        if input == nil {
            println("Couldn't set up camera")
        } else {
            // add video into main view
            session.addInput(input!)
            var previewLayer = AVCaptureVideoPreviewLayer.layerWithSession(session) as AVCaptureVideoPreviewLayer
            previewLayer.frame = mainView.bounds
            mainView.layer.insertSublayer(previewLayer, atIndex: 0)
            session.startRunning()
            cameraReady = true
        }

        self.setUpObservers()
        self.sayReady()
    }

    func setUpObservers() {
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("locationUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.locationReady = self.appDelegate.currentLocation != nil
            self.sayReady()
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("headingUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.headingReady = self.appDelegate.currentDirection != nil
            if self.headingReady {
                self.headingText.text = NSString(format: "Heading: %.02f", self.appDelegate.currentDirection!)
            } else {
                self.headingText.text = ""
            }
            self.sayReady()
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("pitchUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.pitchReady = self.appDelegate.currentPitch != nil
            if self.pitchReady {
                self.pitchText.text = NSString(format: "Pitch: %.02f", self.appDelegate.currentPitch!)
            } else {
                self.pitchText.text = ""
            }

            if self.appDelegate.currentYaw != nil {
                self.yawText.text = NSString(format: "Yaw: %.02f", self.appDelegate.currentYaw!)
            } else {
                self.yawText.text = ""
            }

            if self.appDelegate.currentRoll != nil {
                self.rollText.text = NSString(format: "Roll: %.02f", self.appDelegate.currentRoll!)
            } else {
                self.rollText.text = ""
            }

            self.sayReady()
        }))
    }

    func cancelObservers() {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
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
        let geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(spottedLocation, completionHandler: { (placemarks: [AnyObject]!, error: NSError!) in
            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)

            // Apple Maps Action
            let appleMapsAction = UIAlertAction(title: "Open in Maps", style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                let locURL = NSURL(string: "http://maps.apple.com/?ll=\(self.spottedLocation!.coordinate.latitude),\(self.spottedLocation!.coordinate.longitude)")!
                UIApplication.sharedApplication().openURL(locURL)
            })
            actionSheet.addAction(appleMapsAction)

            // Google Maps action
            if UIApplication.sharedApplication().canOpenURL(NSURL(string: "comgooglemaps://")!) {
                let action = UIAlertAction(title: "Open in Google Maps", style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                    let str = "comgooglemaps://?center=\(self.spottedLocation!.coordinate.latitude),\(self.spottedLocation!.coordinate.longitude)"
                    UIApplication.sharedApplication().openURL(NSURL(string: str)!)
                })
                actionSheet.addAction(action)
            }

            // Share url action
            let shareLinkAction = UIAlertAction(title: "Share Link", style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                let locURL = NSURL(string: "http://maps.apple.com/?ll=\(self.spottedLocation!.coordinate.latitude),\(self.spottedLocation!.coordinate.longitude)")!
                let sheet = UIActivityViewController(activityItems: [locURL], applicationActivities: nil)
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
            actionSheet.addAction(shareLinkAction)

            // Share text action
            let shareTextAction = UIAlertAction(title: "Share Latitude and Longitude", style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                let locString = "\(self.spottedLocation!.coordinate.latitude), \(self.spottedLocation!.coordinate.longitude)"
                let sheet = UIActivityViewController(activityItems: [locString], applicationActivities: nil)
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
            actionSheet.addAction(shareTextAction)

            // Share GPX action
            let shareGPXAction = UIAlertAction(title: "GPX File", style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                let actpro = GPXFileActivityProvider(location: self.spottedLocation!)
                let share = self.mapViewController.toolbarItems![1] as UIBarButtonItem
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
                self.mapViewController.presentViewController(sheet, animated: true, completion: nil)
            })
            actionSheet.addAction(shareGPXAction)

            // Share VCard action
            let shareVCardAction = UIAlertAction(title: "VCard", style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction!) -> Void in
                // Generate VCard with location as home
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

                    let sheet = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    sheet.excludedActivityTypes =
                        [UIActivityTypePostToWeibo,
                            UIActivityTypePrint,
                            UIActivityTypeSaveToCameraRoll,
                            UIActivityTypeAddToReadingList,
                            UIActivityTypePostToFlickr,
                            UIActivityTypePostToVimeo,
                            UIActivityTypePostToTencentWeibo]
                    self.mapViewController.presentViewController(sheet, animated: true, completion: nil)
                } else {
                    let alert = UIAlertController(title: "Failed", message: "Couldn't generate VCard.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
                    self.mapViewController.presentViewController(alert, animated: true, completion: nil)
                }
            })
            actionSheet.addAction(shareVCardAction)

            // Cancel action
            let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
            actionSheet.addAction(cancelAction)

            self.mapViewController.presentViewController(actionSheet, animated: true, completion: nil)
        })
    }

    @IBAction func tapGestureAction(sender: UITapGestureRecognizer) {
        if ready {
            cancelObservers()
            var tapLocation = sender.locationInView(self.view)
            textField.text = "Looking..."
            activityIndicator.startAnimating()
            working = true
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                self.spottedLocation = walkOutFrom(self.appDelegate.currentLocation!,
                    self.getDirection(Double(tapLocation.y)),
                    self.getPitch(Double(tapLocation.x)))

                if self.spottedLocation != nil {
                    self.mapViewController.locationSpotted = self.spottedLocation
                    self.textField.text = "Found!"

                    self.presentViewController(self.mapViewNavController, animated: true, completion: {
                        self.activityIndicator.stopAnimating()
                        self.sayReady()
                        self.setUpObservers()
                        self.working = false
                    })
                } else {
                    self.textField.text = "Failed!"
                    let alert = UIAlertController(title: "Failed", message: "Couldn't spot a location.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
                    self.presentViewController(alert, animated: true, completion: {
                        self.activityIndicator.stopAnimating()
                        self.sayReady()
                        self.setUpObservers()
                        self.working = false
                    })
                }
            })
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
            self.cancelObservers()
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