//
//  SavedViewController.swift
//  SeeThere
//
//  Created by Cameron Little on 3/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreData

class SavedViewController: UITableViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

    private var appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    private var managedObjectContext: NSManagedObjectContext {
        get {
            return appDelegate.managedObjectContext
        }
    }

    lazy private var pageController: PageController = {
        return self.navigationController!.parentViewController as! PageController
    }()

    @IBOutlet var table: UITableView!

    private var data: [LocationInformation] {
        var error: NSError?
        let request = NSFetchRequest(entityName: "LocationInformation")
        let fetched = self.managedObjectContext.executeFetchRequest(request, error: &error) as? [LocationInformation]
        if error != nil {
            //DEBUG
            self.alertError("Failed to fetch stored data.") {}
        }
        if let sources = fetched {
            return sources
        } else {
            return []
        }
    }

    override func viewDidLoad() {
        table.delegate = self
        table.dataSource = self

        table.allowsMultipleSelectionDuringEditing = true
        table.allowsSelectionDuringEditing = true

        navigationItem.title = "Saved Locations"

        setControls()
    }

    override func viewWillAppear(animated: Bool) {
        managedObjectContext.reset()
        table.reloadData()
    }

    func setControls() {
        let backButton = UIBarButtonItem(title: "Camera", style: .Plain, target: pageController, action: "selectCamera")
        navigationItem.leftBarButtonItem = backButton

        let editButton = UIBarButtonItem(title: "Edit", style: .Plain, target: self, action: "edit")
        navigationItem.rightBarButtonItem = editButton
    }

    private var oldDataSource: UIPageViewControllerDataSource?

    func edit() {
        oldDataSource = pageController.dataSource
        pageController.dataSource = nil
        let doneButton = UIBarButtonItem(title: "Done", style: .Done, target: self, action: "doneEditing")
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = nil

        let deleteButton = UIBarButtonItem(title: "Delete", style: .Plain, target: self, action: "deleteMultiple")
        toolbarItems = [deleteButton]
        navigationController?.setToolbarHidden(false, animated: true)

        table.setEditing(true, animated: true)
    }
    func doneEditing() {
        pageController.dataSource = oldDataSource
        setControls()
        table.setEditing(false, animated: true)
        navigationController?.setToolbarHidden(true, animated: true)
    }

    func deleteMultiple() {
        if let selected = self.table.indexPathsForSelectedRows() as? [NSIndexPath] {
            var toDelete = [LocationInformation]()
            for selection in selected {
                toDelete.append(data[selection.item])
            }
            for item in toDelete {
                managedObjectContext.deleteObject(item)
            }
            table.deleteRowsAtIndexPaths(selected, withRowAnimation: UITableViewRowAnimation.Automatic)

            var error: NSError?
            managedObjectContext.save(&error)
        }
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let idx = indexPath.item
        let li = data[idx]
        let id = li.dateTime.description

        // check if the cell has been created and can be reused
        if let cell = tableView.dequeueReusableCellWithIdentifier(id) as? UITableViewCell {
            return cell
        }
        let cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: id)
        cell.textLabel?.text = li.name
        cell.detailTextLabel?.text = "\(li.latitude), \(li.longitude)"
        if li.foundLocation == nil {
            cell.backgroundColor = UIColor(red: 0.9921568627, green: 0.8588235294, blue: 0.1254901961, alpha: 0.3)
        }
        if let image = UIImage(data: li.image) {
            // crop image to square
            let size: CGFloat = CGFloat(min(image.size.width, image.size.height))
            let x = (image.size.width - size) / 2.0
            let y = (image.size.height - size) / 2.0

            var cropRect: CGRect
            // respect image orientation metadata
            if (image.imageOrientation == .Left || image.imageOrientation == .Right) {
                cropRect = CGRectMake(y, x, size, size)
            } else {
                cropRect = CGRectMake(x, y, size, size)
            }

            let imageRef = CGImageCreateWithImageInRect(image.CGImage, cropRect)

            let cropped = UIImage(CGImage: imageRef)

            cell.imageView?.image = cropped
            cell.imageView?.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        }
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            managedObjectContext.deleteObject(data[indexPath.item])

            var error: NSError?
            if !managedObjectContext.save(&error) {
                //DEBUG
                alertError("Error saving: \(error)", handler: {})
            }
        } else {
            println("Unhandled editing style! \(editingStyle)");
        }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        // TODO: display map view
        if table.editing {
            return
        }

        let locationInformation = data[indexPath.item]

        if locationInformation.foundLocation != nil {
            pageController.displayMap(locationInformation) {
                tableView.deselectRowAtIndexPath(indexPath, animated: true)
            }
        } else {
            let location = locationInformation.location
            let pitch = locationInformation.pitch
            let direction = locationInformation.heading

            let cell = table.cellForRowAtIndexPath(indexPath)!
            let loadingView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
            loadingView.activityIndicatorViewStyle = .Gray
            loadingView.hidden = false
            loadingView.startAnimating()
            cell.accessoryView = loadingView
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
            //table.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)

            let work = NSBlockOperation()
            work.addExecutionBlock({
                let (loc, error) = walkOutFrom(location, pitch, direction, work, nil)

                dispatch_async(dispatch_get_main_queue(), {
                    if error == nil || error?.code == 0 && !work.cancelled {
                        if loc != nil {
                            let found = NSEntityDescription.insertNewObjectForEntityForName("FoundLocation", inManagedObjectContext: self.managedObjectContext) as! FoundLocation
                            found.location = loc!
                            locationInformation.foundLocation = found
                        }

                        var error: NSError?
                        if !self.managedObjectContext.save(&error) {
                            self.alertError("Error saving: \(error)") {}
                        }

                        self.table.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
                    } else {
                        if !work.cancelled {
                            if let m = error?.domain {
                                self.alertError(m) {}
                            } else {
                                self.alertError("Something went wrong") {}
                            }
                        }
                    }
                    cell.accessoryView = nil
                })
            })
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                work.start()
            })
        }
    }

}