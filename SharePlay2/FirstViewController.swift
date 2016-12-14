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
    private let roomName:String = "shareplay-10"
    
    private var isParent:Bool = false
    
    private var myAlert:AlertControlller!
    
    private var firstViewFlag:Bool = true
    @IBOutlet weak var startBtn: UIButton!
    
    @IBOutlet weak var peerTable: UITableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        SVProgressHUD.setDefaultStyle(SVProgressHUDStyle.dark)
        SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.clear)
        initialize()
    }
    override func viewWillAppear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true
       
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let key = keyPath{
            if key == "motherID"{//変化したプロパティがPEERnamearryだった場合
                DispatchQueue.main.async {
                    if self.networkCom.motherID != nil{
                        if self.networkCom.motherID .isEqual(self.peerID) || self.isParent{
                            self.startBtn.isHidden = false
                            SVProgressHUD.dismiss()
                        }else{
                            self.stopClient()
                            self.networkCom.removeObserver(self as NSObject, forKeyPath: "motherID")
                            self.networkCom.removeObserver(self as NSObject, forKeyPath: "peerNameArray")
                            self.segueFirstToSecond()
                            SVProgressHUD.dismiss()
                        }
                    }
                    }
                }else if key == "peerNameArray"{
                if networkCom.peerNameArray.count == 0{
                    DispatchQueue.main.async {
                        self.startBtn.isHidden = true
                    }
                }
                DispatchQueue.main.async {
                    self.peerTable.reloadData()
                }
                
            }
            }
        }
    
    func initialize(){
        self.startBtn.isHidden = true
        let userDefaults = UserDefaults.standard //データ永続化用
        let oldName:String? = userDefaults.string(forKey: "DisplayName")
        let deviceName:String = UIDevice.current.name
        if deviceName == " " || deviceName == "　"{//端末の名前がスペースあるいは半角スペースのとき
            SVProgressHUD.showInfo(withStatus:"アプリを終了して\n設定->一般->情報から\n名前を設定してください")
            self.view.isUserInteractionEnabled = false //操作できなくする。
        }
       
            if oldName == deviceName{
                let peerIDData = userDefaults.data(forKey: "PeerID")
                peerID = NSKeyedUnarchiver.unarchiveObject(with: peerIDData!) as! MCPeerID!
                
            }else{
                
                peerID = MCPeerID(displayName: deviceName)//peerIDの設定端末の名前を渡す
                let peerIDData = NSKeyedArchiver.archivedData(withRootObject: peerID)
                userDefaults.set(peerIDData, forKey: "PeerID")
                userDefaults.set(deviceName, forKey: "DisplayName")
                userDefaults.synchronize()
            }
        networkCom = NetworkCommunicater(withID: peerID)
        
        networkCom.addObserver(self as NSObject, forKeyPath: "motherID", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "peerNameArray", options: [.new,.old], context: nil)
        startBtn.isHidden = true
        peerTable.reloadData()
    }
    func dismissHud(withDelay delay:Double){
        
            DispatchQueue.global().async {
                Thread.sleep(forTimeInterval: delay)
                if self.firstViewFlag{
                SVProgressHUD.dismiss()
                }
            }
    }
    
    
    @IBAction func createBtnTapped(_ sender: AnyObject) {

        myAlert = AlertControlller(titlestr: "部屋を作成", messagestr: "周辺の端末に公開します", okTextstr: "OK", canceltextstr: "キャンセル")
        myAlert.addOkAction(okblock: {(action:UIAlertAction!) -> Void in
            self.startServerWithName(name: self.roomName)//公開ボタンを押すと公開される
                         self.isParent = true //親フラグを立てる
                        SVProgressHUD.show(withStatus: "公開中")
                        self.dismissHud(withDelay: 10)
                                    })
        myAlert.addCancelAction(cancelblock:nil )
        present(myAlert.alert, animated: true, completion: nil)
        
    }
    
    @IBAction func searchBtnTapped(_ sender: AnyObject) {
       myAlert = AlertControlller(titlestr: "部屋を検索", messagestr: "周辺の端末を検索します", okTextstr: "OK", canceltextstr: "キャンセル")
        myAlert.addOkAction(okblock: {(action:UIAlertAction!)-> Void in
            self.isParent = false //親フラグを建てないs
            self.startClientWithName(name: self.roomName)
            DispatchQueue.main.async {
                SVProgressHUD.show(withStatus: "検索中")
                self.dismissHud(withDelay: 9)
            }
            
        })
        myAlert.addCancelAction(cancelblock: nil)
       
        present(myAlert.alert, animated: true, completion: nil)
        }
    @IBAction func startBtnTapped(_ sender: AnyObject) {
            stopServer()
            networkCom.removeObserver(self as NSObject, forKeyPath: "motherID")
            networkCom.removeObserver(self as NSObject, forKeyPath: "peerNameArray")
            segueFirstToSecond()
            startBtn.isHidden = true
    }
    //MARK: tableview delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return  networkCom.peerNameArray.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell",for: indexPath)
        if indexPath.row < networkCom.peerNameArray.count{
            let peerName = networkCom.peerNameArray[indexPath.row]
            cell.textLabel!.text = peerName

        }else{
            cell.textLabel?.text = nil
        }
        

    
        return cell

    }
    //MARK: MCSessiondelegate
    // 接続状況が変化したとき.

    //相手を見つけたとき
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?){
        
        SVProgressHUD.dismiss()
        myAlert = AlertControlller(titlestr: "この相手に接続しますか？", messagestr: peerID.displayName, okTextstr: "はい", canceltextstr: "いいえ")
        myAlert.addOkAction(okblock: {(action:UIAlertAction!) -> Void in
            browser.invitePeer(peerID, to: self.networkCom.session, withContext: nil, timeout: 0)
            
        })
        myAlert.addCancelAction(cancelblock: {(alert:UIAlertAction) -> Void in})
        var baseView: UIViewController = self.view.window!.rootViewController!
        while baseView.presentedViewController != nil && !baseView.presentedViewController!.isBeingDismissed {
            baseView = baseView.presentedViewController!
        }
        baseView.present(myAlert.alert, animated: true, completion: nil)

           }
    //MARK: MCNearbyserviceadvitiserdelegate
    //招待されたとき
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Swift.Void){
        
            
        
    
        SVProgressHUD.dismiss()
            myAlert = AlertControlller(titlestr: "接続要求", messagestr: peerID.displayName, okTextstr: "許可", canceltextstr: "拒否")
        myAlert.addOkAction(okblock: {(action:UIAlertAction!) -> Void in
            
            invitationHandler(true,self.networkCom.session)
        })
        myAlert.addCancelAction(cancelblock: {(action:UIAlertAction!) -> Void in
            
            invitationHandler(false,self.networkCom.session)
        })
        var baseView: UIViewController = self.view.window!.rootViewController!
        while baseView.presentedViewController != nil && !baseView.presentedViewController!.isBeingDismissed {
                baseView = baseView.presentedViewController!
            }
        baseView.present(myAlert.alert, animated: true, completion:nil)
        
        
        
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
             firstViewFlag = false
            let secondViewController:SecondViewController = segue.destination as! SecondViewController
            secondViewController.networkCom = self.networkCom
            secondViewController.isParent = self.isParent
            secondViewController.peerID = self.peerID
        }
    }
    @IBAction func backtoFirst(segue:UIStoryboardSegue){//2から1に戻ってきたとき
        firstViewFlag = true
        networkCom.addObserver(self as NSObject, forKeyPath: "motherID", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "peerNameArray", options: [.new,.old], context: nil)

    }
    
    // A nearby peer has stopped advertising.
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID){
        print("lostpeer")
    }
}



