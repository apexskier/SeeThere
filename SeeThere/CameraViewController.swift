//
//  ViewController.swift
//  SeeThere
//
//  Created by Cameron Little on 1/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData
import CoreLocation
import CoreMotion
import Social
import MapKit

func imageFromSampleBuffer(sampleBuffer: CMSampleBufferRef) -> UIImage? {
    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
        CVPixelBufferLockBaseAddress(imageBuffer, 0)

        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)

        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Create a bitmap graphics context with the sample buffer data
        let bitmapInfo = CGBitmapInfo(CGImageAlphaInfo.PremultipliedLast.rawValue)
        if let context = CGBitmapContextCreate(baseAddress, width, height, 8,
            bytesPerRow, colorSpace, bitmapInfo) {
            // Create a Quartz image from the pixel data in the bitmap graphics context
            let quartzImage = CGBitmapContextCreateImage(context)
            // Unlock the pixel buffer
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0)

            // Create an image object from the Quartz image
            let image = UIImage(CGImage: quartzImage)!

            return image
        }
    }
    return nil
}

class CameraViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet var mainView: UIView!
    @IBOutlet weak var textField: UILabel!
    @IBOutlet weak var initialInstructions: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var pitchText: UITextField!
    @IBOutlet weak var yawText: UITextField!
    @IBOutlet weak var rollText: UITextField!
    @IBOutlet weak var headingText: UITextField!

    private var appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    private var managedObjectContext: NSManagedObjectContext {
        get {
            return appDelegate.managedObjectContext
        }
    }

    func sayReady() {
        if ready {
            textField.text = NSLocalizedString("Ready", comment: "text when ready to go")
            hideBlur()
            if firstTime {
                initialInstructions.text = NSLocalizedString("Instructions", comment: "initial instructions")
                initialInstructions.hidden = false
            }
        } else {
            textField.text = NSLocalizedString("GettingReady", comment: "text when waiting for something to be ready")
            showBlur()
        }
    }

    private var firstTime = true

    func hideBlur() {
        self.blurView.hidden = true
        self.activityIndicator.stopAnimating()
    }
    func showBlur() {
        self.blurView.hidden = false
        self.activityIndicator.startAnimating()
    }

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

    private var cameraSession: AVCaptureSession?
    private var cameraInput: AVCaptureDeviceInput?
    private lazy var blurView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.Dark))
        v.frame = self.mainView.bounds
        return v
    }()
    private var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    private var imageOutput: AVCaptureStillImageOutput?

    func die() {
        fatalError("died")
    }

    private var fovVertical: Double = 0
    private var fovHorizontal: Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        var canCamera = false

        let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch authorizationStatus {
        case .NotDetermined:
            // permission dialog not yet presented, request authorization
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (granted:Bool) -> Void in
                if granted {
                    canCamera = true
                }
            })
        case .Authorized:
            canCamera = true
        case .Denied, .Restricted:
            canCamera = false
        }

        if !canCamera {
            self.alertError("You either cannot or won't let the camera be used.") { self.die() }
        } else {
            // Camera capture session
            cameraSession = AVCaptureSession()
            cameraSession!.sessionPreset = AVCaptureSessionPresetHigh

            // input device
            let camera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
            if camera == nil {
                self.alertError(NSLocalizedString("FailedCamera", comment: "failed, camera error")) { self.die() }
            }

            // set camera configuration
            var error: NSError?
            camera.lockForConfiguration(&error)
            if error != nil {
                println(error!.domain)
                self.alertError(NSLocalizedString("FailedCamera", comment: "failed, camera error")) { self.die() }
            }
            camera.focusMode = AVCaptureFocusMode.Locked
            camera.unlockForConfiguration()

            // get camera input stream
            let possibleCameraInput: AnyObject? = AVCaptureDeviceInput.deviceInputWithDevice(camera, error: &error)
            if let cameraInput = possibleCameraInput as? AVCaptureDeviceInput {
                if self.cameraSession!.canAddInput(cameraInput) {
                    self.cameraSession!.addInput(cameraInput)
                } else {
                    self.alertError(NSLocalizedString("FailedCamera", comment: "failed, camera error")) { self.die() }
                }
            } else {
                self.alertError(NSLocalizedString("FailedCamera", comment: "failed, camera error")) { self.die() }
            }

            // set visual camera preview up
            cameraPreviewLayer = AVCaptureVideoPreviewLayer.layerWithSession(self.cameraSession) as? AVCaptureVideoPreviewLayer
            cameraPreviewLayer!.frame = self.mainView.bounds
            cameraPreviewLayer!.connection.videoScaleAndCropFactor = 1
            self.mainView.layer.insertSublayer(cameraPreviewLayer!, atIndex: 0)
            self.mainView.layer.insertSublayer(self.blurView.layer, atIndex: 1)

            // get connection to capture pictures from
            imageOutput = AVCaptureStillImageOutput()
            cameraSession!.addOutput(imageOutput)

            // start the preview up
            cameraSession!.startRunning()

            fovVertical = radians(Double(camera.activeFormat.videoFieldOfView))
            fovHorizontal = radians((width / height) * fovVertical)
        }

        initialInstructions.hidden = true

        cameraReady = true
        cancelButton.hidden = true

        progressBar.hidden = true
        progressBar.progress = 0

        setUpObservers()
        sayReady()

        tapGestureRecognizer.requireGestureRecognizerToFail(tripleTapGestureRecognizer)
    }

    override func viewWillAppear(animated: Bool) {
        pitchText.hidden = true
        yawText.hidden = true
        rollText.hidden = true
        headingText.hidden = true
    }

    func setUpObservers() {
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("locationUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.locationReady = (self.appDelegate.currentLocation != nil) &&
                (self.appDelegate.currentLocation!.horizontalAccuracy > 0) &&
                //(self.appDelegate.currentLocation!.horizontalAccuracy < 60) &&
                (self.appDelegate.currentLocation!.verticalAccuracy > 0) //&&
                //(self.appDelegate.currentLocation!.verticalAccuracy < 40)
            self.sayReady()
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("headingUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.headingReady = self.appDelegate.currentDirection != nil
            if self.headingReady {
                self.headingText.text = NSString(format: "Heading: %.02f", self.appDelegate.currentDirection!) as String
            } else {
                self.headingText.text = ""
            }
            self.sayReady()
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("pitchUpdated", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.pitchReady = self.appDelegate.currentPitch != nil
            if self.pitchReady {
                self.pitchText.text = NSString(format: "Pitch: %.02f", self.appDelegate.currentPitch!) as String
            } else {
                self.pitchText.text = ""
            }

            if self.appDelegate.currentYaw != nil {
                self.yawText.text = NSString(format: "Yaw: %.02f", self.appDelegate.currentYaw!) as String
            } else {
                self.yawText.text = ""
            }

            if self.appDelegate.currentRoll != nil {
                self.rollText.text = NSString(format: "Roll: %.02f", self.appDelegate.currentRoll!) as String
            } else {
                self.rollText.text = ""
            }

            self.sayReady()
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("progressEvent", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification: NSNotification!) -> Void in
            self.progressBar.progress = notification.object as! Float
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

    func closeMap() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    var baseScale: CGFloat = 1
    var effectiveScale: CGFloat = 1
    @IBAction func pinchGestureAction(gesture: UIPinchGestureRecognizer) {
        // Pinch to zoom.
        if gesture.state == UIGestureRecognizerState.Began {
            baseScale = effectiveScale
        } else if gesture.state == UIGestureRecognizerState.Changed {
            effectiveScale = min(max(1, baseScale * gesture.scale), 8)

            let affineTransform = CGAffineTransformMakeScale(effectiveScale, effectiveScale)
            cameraPreviewLayer!.setAffineTransform(affineTransform)

            /* The following should work if hardware zoom is supported.

            let lowerBound = max(1.0, gesture.scale * cameraPreviewLayer!.connection.videoScaleAndCropFactor)
            let upperBound = min(lowerBound, cameraPreviewLayer!.connection.videoMaxScaleAndCropFactor)
            cameraPreviewLayer!.connection.videoScaleAndCropFactor = upperBound*/
        }
    }

    @IBOutlet weak var cancelButton: UIButton!
    @IBAction func cancelAction(sender: AnyObject) {
        cancelButton.hidden = true
        if work != nil && !work!.finished && !work!.cancelled {
            work?.cancel()
        }
    }
    var work: NSBlockOperation?
    func workDone() {
        self.cameraSession!.startRunning()
        self.setUpObservers()
        self.sayReady()
        self.progressBar.hidden = true
    }
    @IBOutlet var tapGestureRecognizer: UITapGestureRecognizer!
    @IBAction func tapGestureAction(sender: UITapGestureRecognizer) {
        if ready {
                initialInstructions.hidden = true
                cancelObservers()

                let tapLocation = sender.locationInView(self.view)

                let location = self.appDelegate.currentLocation!
                let pitch = self.getPitch(Double(tapLocation.y))
                let direction = self.getDirection(Double(tapLocation.x))

                self.textField.text = NSLocalizedString("Looking", comment: "looking for location")
                //self.activityIndicator.startAnimating()
                self.progressBar.progress = 0
                self.progressBar.hidden = false
                self.working = true
                self.cancelButton.hidden = false

                let connection = self.imageOutput!.connectionWithMediaType(AVMediaTypeVideo)
                imageOutput!.captureStillImageAsynchronouslyFromConnection(connection, completionHandler: { (sampleBuffer: CMSampleBuffer!, error: NSError!) -> Void in
                    self.cameraSession!.stopRunning()
                    if error != nil {
                        self.alertError("Something went wrong: \(error?.domain)") {}
                    } else {
                        let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                        if let image = UIImage(data: imageData) {
                            self.work = NSBlockOperation()
                            self.work!.addExecutionBlock({
                                let (loc, error) = walkOutFrom(location, direction, pitch, self.work!, self)

                                dispatch_async(dispatch_get_main_queue(), {
                                    let new = NSEntityDescription.insertNewObjectForEntityForName("LocationInformation", inManagedObjectContext: self.managedObjectContext) as! LocationInformation
                                    new.location = location
                                    new.heading = direction
                                    new.pitch = pitch
                                    new.dateTime = NSDate()
                                    new.image = imageData
                                    new.name = new.dateTime.description

                                    self.working = false
                                    self.cancelButton.hidden = true

                                    if error == nil || error?.code == 0 && !self.work!.cancelled {
                                        self.textField.text = NSLocalizedString("Found", comment: "found a location")

                                        if loc != nil {
                                            let found = NSEntityDescription.insertNewObjectForEntityForName("FoundLocation", inManagedObjectContext: self.managedObjectContext) as! FoundLocation
                                            found.location = loc!
                                            new.foundLocation = found
                                        }

                                        let pageController = self.parentViewController as! PageController
                                        pageController.displayMap(new) {
                                            self.workDone()
                                        }
                                    } else {
                                        if self.work!.cancelled {
                                            self.managedObjectContext.reset()
                                            self.workDone()
                                        } else {
                                            self.textField.text = NSLocalizedString("Failed", comment: "failed to find a location")

                                            var message: String
                                            if let m = error?.domain {
                                                message = m
                                            } else {
                                                message = "Something went wrong."
                                            }
                                            message = NSLocalizedString("SaveQMessageFailed", comment: "asking for save after failure") + message

                                            let alert = UIAlertController(title: NSLocalizedString("SaveQTitle", comment: "ask to save"), message: message, preferredStyle: .Alert)
                                            alert.addTextFieldWithConfigurationHandler { (textField: UITextField!) -> Void in
                                                textField.placeholder = "Name this location"
                                            }
                                            alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: "okay"), style: .Default, handler: { (action: UIAlertAction!) -> Void in
                                                let textField = alert.textFields![0] as! UITextField

                                                new.name = textField.text
                                                var error: NSError?
                                                if !self.managedObjectContext.save(&error) {
                                                    self.alertError("Error saving: \(error)") {}
                                                }
                                                self.workDone()
                                            }))
                                            alert.addAction(UIAlertAction(title: NSLocalizedString("No", comment: "no"), style: UIAlertActionStyle.Cancel, handler: { (action: UIAlertAction!) -> Void in
                                                self.managedObjectContext.reset()
                                                self.workDone()
                                            }))
                                            
                                            self.presentViewController(alert, animated: true) {}
                                        }
                                    }
                                })
                            })
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                                self.work!.start()
                            })
                        } else {
                            self.alertError("Faile to get image") {}
                        }
                    }
                })
            }
    }
    @IBOutlet var tripleTapGestureRecognizer: UITapGestureRecognizer!
    @IBAction func tripleTapGestureAction(sender: UITapGestureRecognizer) {
        if headingText.hidden {
            pitchText.hidden = false
            yawText.hidden = false
            rollText.hidden = false
            headingText.hidden = false
        } else {
            pitchText.hidden = true
            yawText.hidden = true
            rollText.hidden = true
            headingText.hidden = true
        }
    }

    internal func updateProgress(object: AnyObject?) {
        let val: Float = object as! Float
        progressBar.progress = val
    }

    private var screenRect = UIScreen.mainScreen().bounds
    lazy private var width: Double = {
        return Double(self.screenRect.size.width)
    }()
    lazy private var height: Double = {
        return Double(self.screenRect.size.height)
    }()

    func getPitch(pointY: Double) -> Double {
        let h = height / 2
        let a = h / tan(fovVertical / 2)
        let offset = h - pointY
        let offsetAngle = atan2(offset, a) / Double(effectiveScale)

        return appDelegate.currentPitch! + offsetAngle
    }

    func getDirection(pointX: Double) -> CLLocationDirection {
        let w = width / 2
        let a = w / tan(fovHorizontal / 2)
        let offset = pointX - w
        let offsetAngle = atan2(offset, a) / Double(effectiveScale)

        return appDelegate.currentDirection! + offsetAngle
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
