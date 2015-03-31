//
//  PageController.swift
//  SeeThere
//
//  Created by Cameron Little on 3/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreLocation

class PageController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {

    let pageIds: NSArray = ["CameraView", "SavedView"]
    var index = 0

    var panDelegate: UIGestureRecognizerDelegate?

    override func viewDidLoad() {
        self.dataSource = self
        self.delegate = self

        let startingViewController = self.viewControllerAtIndex(self.index)
        let viewControllers: NSArray = [startingViewController]
        self.setViewControllers(viewControllers as! [AnyObject], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)
    }

    /*override func gestureRecognizer(gestureRecognizer: UIPanGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
    }*/

    func viewControllerAtIndex(index: Int) -> UIViewController! {
        switch index {
        case 0:
            return self.storyboard?.instantiateViewControllerWithIdentifier("CameraView") as! UIViewController
        case 1:
            return self.storyboard?.instantiateViewControllerWithIdentifier("SavedView") as! UIViewController
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

    private var nextCompletion: (() -> Void) = {}
    func displayMap(location: CLLocation, completion: (() -> Void)) {
        // fetch the mapviewcontroller
        self.nextCompletion = completion
        if let map = self.storyboard?.instantiateViewControllerWithIdentifier("MapView") as? MapViewController {
            // define actionbuttons
            let done = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: "closeMap")
            let share = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: map, action: "actionLocation")
            let flex = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
            let switchMap = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.PageCurl, target: map, action: "switchMapStyle")

            // add action buttons
            map.navigationItem.leftBarButtonItem = done
            map.toolbarItems = [flex, share, flex, switchMap]

            // set up a navigation controller
            let mapNav = UINavigationController(rootViewController: map)
            mapNav.toolbarHidden = false

            // tell it where the location is
            map.spottedLocation = location

            // show map view
            self.presentViewController(mapNav, animated: true, completion: nil)
        } else {
            alertError("Failed to open map.") {}
        }
    }

    func closeMap() {
        self.dismissViewControllerAnimated(true, completion:
            nextCompletion)
    }
}