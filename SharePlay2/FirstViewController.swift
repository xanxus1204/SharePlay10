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
    
    private let roomName:String = "shareplay10"
    
    private var isParent:Bool = false
    
    private var alert:UIAlertController!
    
    @IBOutlet weak var startBtn: UIButton!
    
    @IBOutlet weak var roomLabel: UILabel!
    
    @IBOutlet weak var peerTable: UITableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SVProgressHUD.setDefaultStyle(SVProgressHUDStyle.dark)
        SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.clear)
        initialize()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let key = keyPath{
            if key == "peerNameArray"{//変化したプロパティがPEERnamearryだった場合
                DispatchQueue.main.async {
                    self.peerTable.reloadData()
                    if self.isParent{
                        self.startBtn.isHidden = false
                        SVProgressHUD.dismiss()
                    }else{
                        self.networkCom.removeObserver(self as NSObject, forKeyPath: "peerNameArray")
                        self.segueFirstToSecond()
                        SVProgressHUD.dismiss()
                    }
                }

            }
        }
        
    }
    func initialize(){
        let userDefaults = UserDefaults.standard //データ永続化用
        let oldName:String? = userDefaults.string(forKey: "DisplayName")
        let deviceName:String = UIDevice.current.name
        if let old = oldName{
            if old == deviceName{
                let peerIDData = userDefaults.data(forKey: "PeerID")
                peerID = NSKeyedUnarchiver.unarchiveObject(with: peerIDData!) as! MCPeerID!
                print("前回のIDを再利用")
            }
        }else{
            
             peerID = MCPeerID(displayName: deviceName)//peerIDの設定端末の名前を渡す
            let peerIDData = NSKeyedArchiver.archivedData(withRootObject: peerID)
            userDefaults.set(peerIDData, forKey: "PeerID")
            userDefaults.set(deviceName, forKey: "DisplayName")
            userDefaults.synchronize()
        }
       
        
        networkCom = NetworkCommunicater()
        networkCom.createSessionwithID(peerID: peerID)
        networkCom.prepare()
        networkCom.addObserver(self as NSObject, forKeyPath: "peerNameArray", options: [.new,.old], context: nil)
        startBtn.isHidden = true
        roomLabel.text = nil
        peerTable.reloadData()
    }
    func dismissHud(withDelay delay:Double){
        DispatchQueue.global().async {
            Thread.sleep(forTimeInterval: delay)
            SVProgressHUD.dismiss()
        }
       
    }
    
    
    @IBAction func createBtnTapped(_ sender: AnyObject) {

        
        
         alert = UIAlertController(title: "部屋を作成", message: "周辺の端末に公開します", preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {(action:UIAlertAction!)-> Void in
            self.startServerWithName(name: self.roomName)//公開ボタンを押すと公開される
             self.isParent = true //親フラグを立てる
            SVProgressHUD.show(withStatus: "公開中")
            self.dismissHud(withDelay: 7)
        })
        let cancelAction = UIAlertAction(title: "キャンセル", style: UIAlertActionStyle.cancel, handler:nil)
        alert.addAction(cancelAction)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func searchBtnTapped(_ sender: AnyObject) {
       
        roomLabel.text = nil//部屋番号を表す数字を消す
         alert = UIAlertController(title: "部屋を検索", message: "周辺の端末を検索します", preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
            {(action:UIAlertAction!)-> Void in
                        self.isParent = false //親フラグを建てないs
                        self.startClientWithName(name: self.roomName)
                        DispatchQueue.main.async {
                            SVProgressHUD.show(withStatus: "検索中")
                            self.dismissHud(withDelay: 7)
                        }
            
        })
        let cancelAction = UIAlertAction(title: "キャンセル", style: UIAlertActionStyle.cancel, handler:nil)
        //let anotherAction = UIAlertAction(title: "以前接続した相手を検索", style: UIAlertActionStyle.default, handler: {(action:UIAlertAction) -> Void in})
        alert.addAction(okAction)
        alert.addAction(cancelAction)
       // alert.addAction(anotherAction)
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
        stopClient()//サーバーとしての作業及びクライアントとしての作業をどちらもやめる
        stopServer()
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
        stopClient()
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
        self.networkCom.disconnectPeer()
        print("戻ってきた")
        self.viewDidLoad()
        
    }
    
    // A nearby peer has stopped advertising.
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID){
    }
}



