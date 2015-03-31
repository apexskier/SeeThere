//
//  PageController.swift
//  SeeThere
//
//  Created by Cameron Little on 3/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation
import UIKit

class PageController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    let pageIds: NSArray = ["CameraView", "SavedView"]
    var index = 0

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
            self.index = self.index + 1
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
            self.index = self.index - 1
            return self.viewControllerAtIndex(self.index)
        }
        return nil
    }

    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return self.pageIds.count
    }

    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 0
    }
}