//
//  ViewController.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/09/29.
//  Copyright © 2016年 椛島優. All rights reserved.
//

import UIKit
// first commit

class FirstViewController: UIViewController,UITextFieldDelegate,UITableViewDataSource,UITableViewDelegate {
    @IBOutlet weak var textField: UITextField!

    @IBOutlet weak var peerTable: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        //textfieldの終了イベント用delegate
        textField.delegate = self
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func createBtnTapped(_ sender: AnyObject) {
    }
    
    @IBAction func searchBtnTapped(_ sender: AnyObject) {
    }
    @IBAction func startBtnTapped(_ sender: AnyObject) {
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "1to2" {
            // インスタンスの引き継ぎ
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //画面がタッチされたときの呼ばれるメソッド　ボタンなどは対象外
        textField.endEditing(true)
    }
    
    // MARK: tableview delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return  1
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell",for: indexPath)
    
        return cell

    }
}



