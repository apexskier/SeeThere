//
//  SavedViewController.swift
//  SeeThere
//
//  Created by Cameron Little on 3/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreData

class SavedViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

    private var appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    private var managedObjectContext: NSManagedObjectContext {
        get {
            return appDelegate.managedObjectContext
        }
    }

    @IBOutlet weak var table: UITableView!
    @IBOutlet weak var bottomToolbar: UIToolbar!

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
        self.table.dataSource = self
        self.table.delegate = self

        let backButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Rewind, target: self, action: nil)

        let buttons = [backButton]

        //topNavigation.items = buttons
        //bottomToolbar.items = buttons
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
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
            cell.backgroundColor = appDelegate.window?.tintColor
        }
        let image = UIImage(data: li.image)
        cell.imageView?.image = image
        return cell
    }

    /*
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int

    // Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
    // Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    */

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
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

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        // TODO: display map view
        let locationInformation = data[indexPath.item]

        if let location = locationInformation.foundLocation?.location {
            let pageController = self.parentViewController as! PageController
            pageController.displayMap(location) {
                tableView.deselectRowAtIndexPath(indexPath, animated: true)
            }
        } else {



            let location = locationInformation.location
            let pitch = locationInformation.pitch
            let direction = locationInformation.heading



            let work = NSBlockOperation()
            work.addExecutionBlock({
                let (loc, error) = walkOutFrom(location, pitch, direction, work)

                dispatch_async(dispatch_get_main_queue(), {
                    let new = NSEntityDescription.insertNewObjectForEntityForName("LocationInformation", inManagedObjectContext: self.managedObjectContext) as! LocationInformation
                    new.location = location
                    new.heading = direction
                    new.pitch = pitch
                    new.dateTime = NSDate()
                    new.name = new.dateTime.description
                    
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
                        tableView.deselectRowAtIndexPath(indexPath, animated: true)

                        /*let pageController = self.parentViewController as! PageController
                        pageController.displayMap(loc!) {
                            tableView.deselectRowAtIndexPath(indexPath, animated: true)
                        }*/
                    } else {
                        if work.cancelled {
                            tableView.deselectRowAtIndexPath(indexPath, animated: true)
                        } else {
                            if let m = error?.domain {
                                self.askToSave(self.managedObjectContext, message: m, object: new) {
                                    tableView.deselectRowAtIndexPath(indexPath, animated: true)
                                }
                            } else {
                                self.askToSave(self.managedObjectContext, message: "", object: new) {
                                    tableView.deselectRowAtIndexPath(indexPath, animated: true)
                                }
                            }
                        }
                    }
                })
            })
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                work.start()
            })
        }
    }

}