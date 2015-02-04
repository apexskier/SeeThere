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
        let share = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: m, action: "actionLocation")
        let flex = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
        let switchMap = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.PageCurl, target: m, action: "switchMapStyle")

        m.navigationItem.leftBarButtonItem = done
        m.toolbarItems = [flex, share, flex, switchMap]
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
                    self.mapViewController.spottedLocation = self.spottedLocation
                    self.textField.text = "Found!"
                    self.activityIndicator.stopAnimating()
                    self.sayReady()
                    self.presentViewController(self.mapViewNavController, animated: true, completion: {
                        self.setUpObservers()
                        self.working = false
                    })
                } else {
                    self.textField.text = "Failed!"
                    let alert = UIAlertController(title: "Failed", message: "Couldn't spot a location.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
                    self.activityIndicator.stopAnimating()
                    self.sayReady()
                    self.presentViewController(alert, animated: true, completion: {
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