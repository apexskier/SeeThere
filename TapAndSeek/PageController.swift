//
//  PageController.swift
//  TapAndSeek
//
//  Created by Cameron Little on 3/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData

class PageController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {

    let pageIds: NSArray = ["CameraView", "SavedViewNav"]
    var index = 0

    private var appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    private var managedObjectContext: NSManagedObjectContext {
        get {
            return appDelegate.managedObjectContext
        }
    }

    var panDelegate: UIGestureRecognizerDelegate?

    override func viewDidLoad() {
        self.dataSource = self
        self.delegate = self

        let startingViewController = self.viewControllerAtIndex(self.index)
        let viewControllers: NSArray = [startingViewController]
        self.setViewControllers(viewControllers as! [AnyObject], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)
    }

    func viewControllerAtIndex(index: Int) -> UIViewController! {
        switch index {
        case 0:
            return self.storyboard?.instantiateViewControllerWithIdentifier("CameraView") as! UIViewController
        case 1:
            return self.storyboard?.instantiateViewControllerWithIdentifier("SavedViewNav") as! UIViewController
        default:
            return nil
        }
    }

    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        if let identifier = viewController.restorationIdentifier {
            let index = self.pageIds.indexOfObject(identifier)

            // don't go past the last view
            if index == pageIds.count - 1 {
                return nil
            }

            // get next
            self.index++
            return self.viewControllerAtIndex(self.index)
        }
        return nil
    }

    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        if let identifier = viewController.restorationIdentifier {
            let index = self.pageIds.indexOfObject(identifier)

            // don't go before the first view
            if index == 0 {
                return nil
            }

            // get previous
            self.index--
            return self.viewControllerAtIndex(self.index)
        }
        return nil
    }

    func displayMap(locationInformation: LocationInformation, completion: (() -> Void)) {
        // fetch the mapviewcontroller
        if let map = self.storyboard?.instantiateViewControllerWithIdentifier("MapView") as? MapViewController {
            // define actionbuttons
            if locationInformation.objectID.temporaryID {
                let save = UIBarButtonItem(barButtonSystemItem: .Save, target: map, action: "closeMapSave")
                let delete = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action: "closeMapReset")
                map.navigationItem.leftBarButtonItem = save
                map.navigationItem.rightBarButtonItem = delete
            } else {
                let done = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "closeMap")
                let delete = UIBarButtonItem(barButtonSystemItem: .Trash, target: map, action: "deleteItem")
                map.navigationItem.leftBarButtonItem = done
                map.navigationItem.rightBarButtonItem = delete
            }

            // add action buttons
            let share = UIBarButtonItem(barButtonSystemItem: .Action, target: map, action: "actionLocation")
            let flex = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
            let switchMap = UIBarButtonItem(title: "Map Type", style: .Plain, target: map, action: "switchMapStyle")
            map.toolbarItems = [share, flex, switchMap]

            // set up a navigation controller
            let mapNav = UINavigationController(rootViewController: map)
            mapNav.toolbarHidden = false

            // tell it where the location is
            map.locationInformation = locationInformation

            // show map view
            self.presentViewController(mapNav, animated: true, completion: completion)
        } else {
            alertError("Failed to open map.") {}
        }
    }

    func closeMap() {
        var error: NSError?
        managedObjectContext.save(&error)
        if error != nil {
            alertError("Error saving") {}
        }
        dismissViewControllerAnimated(true) {}
    }
    func closeMapReset() {
        managedObjectContext.reset()
        dismissViewControllerAnimated(true) {}
    }

    func selectCamera() {
        index = 0
        let view = viewControllerAtIndex(index)
        setViewControllers([view], direction: UIPageViewControllerNavigationDirection.Reverse, animated: true, completion: nil)
    }
}