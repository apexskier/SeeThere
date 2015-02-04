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

    private var spottedLocation: CLLocation?

    func sayReady() {
        if ready {
            textField.text = NSLocalizedString("Ready", comment: "text when ready to go")
            activityIndicator.stopAnimating()
        } else {
            textField.text = NSLocalizedString("GettingReady", comment: "text when waiting for something to be ready")
            activityIndicator.startAnimating()
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
            return r
        }
    }

    var observers: [AnyObject] = []

    private let camera: AVCaptureDevice = {
        let c = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        var error: NSError?
        c.lockForConfiguration(&error)
        if error != nil {
            fatalError("Couldn't lock to set up camera")
        }
        c.focusMode = AVCaptureFocusMode.Locked
        c.unlockForConfiguration()
        return c
    }()
    private lazy var cameraSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetHigh
        var error: NSError?
        let input: AVCaptureDeviceInput? = AVCaptureDeviceInput.deviceInputWithDevice(self.camera, error: &error) as? AVCaptureDeviceInput
        if input == nil {
            fatalError("Couldn't set up camera capture")
        }
        session.addInput(input!)

        return session
    }()
    private lazy var cameraPreview: AVCaptureVideoPreviewLayer = {
        var layer = AVCaptureVideoPreviewLayer.layerWithSession(self.cameraSession) as AVCaptureVideoPreviewLayer
        layer.frame = self.mainView.bounds
        self.mainView.layer.insertSublayer(layer, atIndex: 0)
        return layer
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        cameraPreview.connection.videoScaleAndCropFactor = 1
        cameraSession.startRunning()
        cameraReady = true

        setUpObservers()
        sayReady()
    }

    func setUpObservers() {
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("locationUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.locationReady = (self.appDelegate.currentLocation != nil) &&
                (self.appDelegate.currentLocation!.horizontalAccuracy > 0) &&
                (self.appDelegate.currentLocation!.horizontalAccuracy < 60) &&
                (self.appDelegate.currentLocation!.verticalAccuracy > 0) &&
                (self.appDelegate.currentLocation!.verticalAccuracy < 40)
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

    @IBAction func pinchGestureAction(gesture: UIPinchGestureRecognizer) {
        if gesture.state == UIGestureRecognizerState.Changed {
            let lowerBound = max(1.0, gesture.scale * cameraPreview.connection.videoScaleAndCropFactor)
            let upperBound = min(lowerBound, cameraPreview.connection.videoMaxScaleAndCropFactor)
            cameraPreview.connection.videoScaleAndCropFactor = upperBound
        }
    }

    @IBAction func tapGestureAction(sender: UITapGestureRecognizer) {
        if ready {
            cancelObservers()
            var tapLocation = sender.locationInView(self.view)
            textField.text = NSLocalizedString("Looking", comment: "looking for location")
            activityIndicator.startAnimating()
            working = true
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                self.spottedLocation = walkOutFrom(self.appDelegate.currentLocation!,
                    self.getDirection(Double(tapLocation.x)),
                    self.getPitch(Double(tapLocation.y)))

                dispatch_async(dispatch_get_main_queue(), {
                    if self.spottedLocation != nil {
                        self.mapViewController.spottedLocation = self.spottedLocation
                        self.textField.text = NSLocalizedString("Found", comment: "found a location")
                              self.presentViewController(self.mapViewNavController, animated: true, completion: {
                            self.setUpObservers()
                            self.working = false
                            self.sayReady()
                        })
                    } else {
                        self.textField.text = NSLocalizedString("Failed", comment: "failed to find a location")
                        self.activityIndicator.stopAnimating()
                        let alert = UIAlertController(title:  NSLocalizedString("Failed", comment: "failed"), message:  NSLocalizedString("FailedLocationMessage", comment: "failed to find a location"), preferredStyle: UIAlertControllerStyle.Alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "okay"), style: UIAlertActionStyle.Cancel, handler: nil))
                        self.presentViewController(alert, animated: true, completion: {
                            self.setUpObservers()
                            self.working = false
                            self.sayReady()
                        })
                    }
                })
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
    lazy private var fovVertical: Double = {
        return radians(Double(self.camera.activeFormat.videoFieldOfView))
    }()
    lazy private var fovHorizontal: Double = {
        return radians((self.width / self.height) * self.fovVertical)
    }()

    func getPitch(pointY: Double) -> Double {
        let a = (height / 2) / tan(fovVertical / 2)

        let offset = height/2 - pointY
        let offsetAngle = atan2(offset, a)

        return appDelegate.currentPitch! + offsetAngle
    }

    func getDirection(pointX: Double) -> CLLocationDirection {
        let a = (width / 2) / tan(fovHorizontal / 2)

        let offset = pointX - width/2
        let offsetAngle = atan2(offset, a)

        return appDelegate.currentDirection! + offsetAngle
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}