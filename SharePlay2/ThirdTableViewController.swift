//
//  ThirdTableViewController.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/11/04.
//  Copyright © 2016年 椛島優. All rights reserved.
//

import UIKit


class ThirdTableViewController: UIViewController,UITableViewDataSource,UITableViewDelegate{
    var fileList:[String] = []
    var filePath:String?
    @IBOutlet weak var fileTable: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        let docDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)[0]
        let manager = FileManager.default
        do {
            fileList = try manager.contentsOfDirectory(atPath: docDir)
            
        } catch  {
            print("できず")
        }

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

     func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
         
        self.filePath =  fileList[indexPath.row]
        performSegue(withIdentifier: "3to2", sender: nil)
    }

     func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return fileList.count
    }

    
     func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell2", for: indexPath)

        // Configure the cell...
        cell.textLabel?.text = fileList[indexPath.row]

        return cell
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "3to2" {
            // インスタンスの引き継ぎ
            let secondViewController:SecondViewController = segue.destination as! SecondViewController
            secondViewController.filePath = self.filePath
        }
    }
    

}
