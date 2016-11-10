//
//  ViewController.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/09/29.
//  Copyright © 2016年 椛島優. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class FirstViewController: UIViewController,UITableViewDataSource,UITableViewDelegate,MCNearbyServiceBrowserDelegate,MCNearbyServiceAdvertiserDelegate{
    
    var peerID:MCPeerID!
    private var browser: MCNearbyServiceBrowser! //ピアーを探索するときに使うオブジェクト
    private var nearbyAd:MCNearbyServiceAdvertiser! //サービスを公開するときに使うオブジェクト
    
    var networkCom:NetworkCommunicater!
    
    private let roomName:String = "abcdefg"
    
    private var roomNum:Int = 0
    
    private var isParent:Bool = false
    
    @IBOutlet weak var startBtn: UIButton!
    
    
    @IBOutlet weak var roomLabel: UILabel!
    

    @IBOutlet weak var peerTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initialize()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
       
        DispatchQueue.main.async {
            self.peerTable.reloadData()
            if self.isParent{
                self.startBtn.isHidden = false
            }else{
                self.networkCom.removeObserver(self as NSObject, forKeyPath: "peerNameArray")
                self.segueFirstToSecond()
            }
        }
        
    }
    func initialize(){
        peerID = MCPeerID(displayName: UIDevice.current.name)//peerIDの設定端末の名前を渡す
        networkCom = NetworkCommunicater()
        networkCom.createSessionwithID(peerID: peerID)
        networkCom.prepare()
        networkCom.addObserver(self as NSObject, forKeyPath: "peerNameArray", options: [.new,.old], context: nil)
        roomNum = 0
        startBtn.isHidden = true
        roomLabel.text = nil
       
        peerTable.reloadData()
    }
    
    @IBAction func createBtnTapped(_ sender: AnyObject) {
        isParent = true
       
        if roomNum == 0 {
            roomNum = createRandomNum() //部屋作成時の４けたの鍵
        }
        let roomNumName = String(describing: roomNum)
        roomLabel.text = roomNumName
        let alert = UIAlertController(title: roomNumName, message: "友達に教えてあげよう", preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "閉じる", style: UIAlertActionStyle.default, handler: {(action:UIAlertAction!)-> Void in
         self.startServerWithName(name: self.roomName + roomNumName)
            
        })
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
       
        
    }
    
    @IBAction func searchBtnTapped(_ sender: AnyObject) {
        isParent = false
        roomLabel.text = nil
            stopClient()
        let alert:UIAlertController = UIAlertController(title: "部屋番号を入力", message: "友達に教えてもらおう", preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "決定", style: UIAlertActionStyle.default, handler:
            {(action:UIAlertAction!)-> Void in
            let textFields:Array<UITextField>? = alert.textFields as Array<UITextField>?
            if textFields != nil{
                    
                    let roomNumName = textFields?[0].text
                    let predicate = NSPredicate(format: "SELF MATCHES '\\\\d+'")//0-9の数字のみ採用
                if predicate.evaluate(with: roomNumName){
                    if self.roomNum != Int(roomNumName!)!{
                        self.startClientWithName(name: self.roomName + roomNumName!)
                        self.roomNum = Int(roomNumName!)!
                        
                        
                    }
                }
            }
        })
        alert.addAction(okAction)
        alert.addTextField(configurationHandler: {(text:UITextField!) -> Void in    text.keyboardType = UIKeyboardType.decimalPad})
        present(alert, animated: true, completion: nil)
            }
    @IBAction func startBtnTapped(_ sender: AnyObject) {
            stopServer()
            networkCom.removeObserver(self as NSObject, forKeyPath: "peerNameArray")
            segueFirstToSecond()
    }
    //MARK: tableview delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return  networkCom.peerNameArray.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell",for: indexPath)
        let peerName = networkCom.peerNameArray[indexPath.row]
        cell.textLabel!.text = peerName
    
        return cell

    }
    
    //MARK: MCSessiondelegate
    // 接続状況が変化したとき.

    //相手を見つけたとき
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?){
        print("見つけた")
        browser.invitePeer(peerID, to: networkCom.session, withContext: nil, timeout: 0)
    }
    //MARK: MCNearbyserviceadvitiserdelegate
    //招待されたとき
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Swift.Void){
        print("招待された")
        invitationHandler(true,networkCom.session)
    }
    //MARK: 自作関数　主にデータ送受信系
    func startServerWithName(name:String?) -> Swift.Void {
        stopClient()
        if name != nil{
            if nearbyAd == nil{
                nearbyAd = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: name!)//サービス用のアドバタイズオブジェクト生成
                nearbyAd.delegate = self//delegate設定
                nearbyAd.startAdvertisingPeer() //サービス公開
            }
           
        }
    }
    func startClientWithName(name:String?) -> Swift.Void {
        stopServer()
        if name != nil{
                browser = MCNearbyServiceBrowser(peer: peerID, serviceType: name!) //探索用オブジェクトの生成
                browser.delegate = self //delegateの設定
                browser.startBrowsingForPeers()//探索の開始
        }
    }
    func stopClient(){
        if browser != nil{
            browser.stopBrowsingForPeers()
            browser.delegate = nil
            browser = nil
        }
    }
    func stopServer(){
        if nearbyAd != nil{
            nearbyAd.stopAdvertisingPeer()
            nearbyAd.delegate = nil
            nearbyAd = nil
        }
    }
    func createRandomNum() -> Int {
        var random = 0
        var returnNum = 0
        var cardinal = 1
        for _ in 0..<4 {
            random = Int(arc4random_uniform(10))
            if random == 0 {
                random = random + 1
            }
            returnNum = returnNum + random * cardinal
            cardinal = cardinal * 10
        }
        return returnNum
    }
    func reConnect(){
        if nearbyAd != nil{
            nearbyAd.stopAdvertisingPeer()
            nearbyAd = nil
        }
        if browser != nil {
            browser.stopBrowsingForPeers()
            browser = nil
        }
        roomNum = 0
        
    }
    
    //MARK: segue
    
    func segueFirstToSecond(){
        performSegue(withIdentifier: "1to2", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "1to2" {
            // インスタンスの引き継ぎ
            
            let secondViewController:SecondViewController = segue.destination as! SecondViewController
            secondViewController.networkCom = self.networkCom
            secondViewController.isParent = self.isParent
            
        }
    }
    @IBAction func backtoFirst(segue:UIStoryboardSegue){//2から1に戻ってきたとき
        initialize()
        print("戻ってきた")
        
        
    }
    
    // A nearby peer has stopped advertising.
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID){
    }
}



