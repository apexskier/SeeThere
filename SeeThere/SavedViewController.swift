//
//  SavedViewController.swift
//  SeeThere
//
//  Created by Cameron Little on 3/30/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import UIKit
import CoreData

class SavedViewController: UITableViewController, UITableViewDataSource {

    private var appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    private var managedObjectContext: NSManagedObjectContext {
        get {
            return appDelegate.managedObjectContext
        }
    }

    private var data: [LocationInformation] {
        var error: NSError?
        let request = NSFetchRequest(entityName: "LocationInformation")
        let fetched = self.managedObjectContext.executeFetchRequest(request, error: &error) as? [LocationInformation]
        if error != nil {
            //DEBUG
            fatalError("couldn't fetch stuff")
        }
        if let sources = fetched {
            return sources
        } else {
            return []
        }
    }

    override func viewWillAppear(animated: Bool) {
        self.tableView.dataSource = self
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
        let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: id)
        cell.textLabel?.text = "\(li.latitude), \(li.longitude)"
        if li.foundLocation == nil {
            cell.backgroundColor = UIColor.blueColor()
        }
        return cell
    }

    /*
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int

    // Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
    // Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    */

}