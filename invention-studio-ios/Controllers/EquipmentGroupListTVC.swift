//
//  EquipmentGroupListTVC.swift
//  invention-studio-ios
//
//  Created by Noah Sutter on 1/23/18.
//  Copyright © 2018 Invention Studio at Georgia Tech. All rights reserved.
//

import UIKit

class EquipmentGroupListTVC: ISTableViewController {
    var equipmentGroups = [Location]()
    var tools = [Tool]()
    // used to ensure refresh is only running once
    var refreshing = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        refresh(nil)
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.equipmentGroups.count
    }
    
    
    // Gets the equipment groups out of a list of tools
    func getEquipmentGroups(tools:[Tool]) -> [Location] {
        var equipmentGroups = Set<Location>()
        for tool in tools {
            if tool.locationId != 0 {
                equipmentGroups.insert(Location(fromTool: tool))
            }
        }
        return equipmentGroups.sorted(by: { (groupA, groupB) in
            return groupA.locationName <= groupB.locationName
        })
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "equipmentGroupPrototype", for: indexPath)
        cell.textLabel?.text = self.equipmentGroups[indexPath.row].locationName

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mVC = storyboard?.instantiateViewController(withIdentifier: "EquipmentGroupTVC") as! EquipmentGroupTVC
        var sentTools = [Tool]()
        for tool in tools {
            if tool.locationId == self.equipmentGroups[indexPath.row].locationId && tool.locationId != 0 {
                //Exclude tools with no location
                sentTools.append(tool)
            }
        }
        mVC.tools = tools
        mVC.groupTools = sentTools
        mVC.location = equipmentGroups[indexPath.row]
        mVC.title = sentTools[0].locationName
        
        // defining the method EquipmentGroupTVC can use to update tools if refreshed
        mVC.backProp = {tools in
            self.tools = tools
            self.equipmentGroups = self.getEquipmentGroups(tools: tools)
            
            // Must be called from main thread, not UIKit
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        // Pushing the new view controller up
        navigationController?.pushViewController(mVC, animated: true)
        self.tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction func refresh(_ sender: Any?) {
        if !refreshing {
            refreshing = true
            if (sender != nil) {
                (sender as! UIRefreshControl).attributedTitle = NSAttributedString(string: "Fetching groups...")
            }
            SumsApi.EquipmentGroup.Tools(completion: { tools, error in
                if error != nil {
                    // sending error alert
                    let parts = error!.components(separatedBy: ":")
                    self.alert(title: parts[0], message: parts[1], sender: sender)
                    self.refreshing = false
                    return
                }
                
                self.tools = tools!
                self.equipmentGroups = self.getEquipmentGroups(tools: tools!)
                // Must be called from main thread, not UIKit
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    if (sender != nil) {
                        // updating refresh title
                        let attributedTitle = NSAttributedString(string: "Last Refresh: Success")
                        (sender as! UIRefreshControl).attributedTitle = attributedTitle
                        
                        // ending refreshing
                        (sender as! UIRefreshControl).endRefreshing()
                    }
                    self.refreshing = false
                }
            })
        }
    }

    func alert(title: String, message: String, sender: Any?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: {
                if sender != nil {
                    let attributedTitle = NSAttributedString(string: "Last Refresh: Failed")
                    (sender as! UIRefreshControl).attributedTitle = attributedTitle
                    (sender as! UIRefreshControl).endRefreshing()
                }
            })
        }
    }
}
