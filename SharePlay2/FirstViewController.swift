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
    
    var peerID:MCPeerID!//これもできれば外で管理したい
    private var browser: MCNearbyServiceBrowser! //ピアーを探索するときに使うオブジェクト
    private var nearbyAd:MCNearbyServiceAdvertiser! //サービスを公開するときに使うオブジェクト
    var networkCom:NetworkCommunicater!
    private let roomName:String = "shareplay-10g"
    
    private var isParent:Bool = false
    
    private var myAlert:AlertControlller!
    
    
    @IBOutlet weak var startBtn: UIButton!
    
    @IBOutlet weak var peerTable: UITableView!
    
    @IBOutlet weak var createBtn: UIButton!
    
    @IBOutlet weak var searchBtn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0)
        peerTable.backgroundColor = UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0)
        initialize()
        SVProgressHUD.setDefaultStyle(SVProgressHUDStyle.dark)
        SVProgressHUD.setDefaultAnimationType(SVProgressHUDAnimationType.native)
        }
    override func viewWillAppear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true
        print("willapper")
        self.startBtn.alpha = 1
        SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.none)
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
                            UIView.animate(withDuration: 1.0, delay: 0, options: [UIViewAnimationOptions.repeat, UIViewAnimationOptions.allowUserInteraction], animations:  {()-> Void in
                                self.startBtn.alpha = 0.1
                            }, completion: nil)
                            
                        }else{
                            self.stopClient()
                            self.networkCom.removeObserver(self as NSObject, forKeyPath: "motherID")
                            self.networkCom.removeObserver(self as NSObject, forKeyPath: "peerNameArray")
                            self.segueFirstToSecond()
                        }
                    }
                    }
                }else if key == "peerNameArray"{
                if networkCom.peerNameArray.count == 0{
                    DispatchQueue.main.async {
                        SVProgressHUD.dismiss()
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
    
    @IBAction func createBtnTapped(_ sender: AnyObject) {
        print("親")
            createBtn.isEnabled = false
            searchBtn.isEnabled = false
                    startServerWithName(name: self.roomName)//公開ボタンを押すと公開される
                    isParent = true //親フラグを立てる
                    SVProgressHUD.show(withStatus: "公開中\nタップして\nキャンセル")
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if networkCom.peerNameArray.count == 0{
            createBtn.isEnabled = true
            searchBtn.isEnabled = true
            SVProgressHUD.dismiss()
            stopClient()
            stopServer()
        }
        
    }
    
    @IBAction func searchBtnTapped(_ sender: AnyObject) {
        print("子")
        self.isParent = false //親フラグを建てないs
        createBtn.isEnabled = false
        searchBtn.isEnabled = false
        self.startClientWithName(name: self.roomName)
        SVProgressHUD.show(withStatus: "検索中\nタップして\nキャンセル")
        
    }
    @IBAction func startBtnTapped(_ sender: AnyObject) {
            SVProgressHUD.dismiss()
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
            print("nilを返している")
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
            SVProgressHUD.show(withStatus: "接続中")
            
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
            SVProgressHUD.show(withStatus: "公開中\n上のボタンをタップして\nスタート")
        })
        myAlert.addCancelAction(cancelblock: {(action:UIAlertAction!) -> Void in
            
            invitationHandler(false,self.networkCom.session)
            SVProgressHUD.show(withStatus: "公開中\nタップして\nキャンセル")
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
        SVProgressHUD.dismiss()
        performSegue(withIdentifier: "1to2", sender: nil)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "1to2" {
            // インスタンスの引き継ぎ
            let secondViewController:SecondViewController = segue.destination as! SecondViewController
            secondViewController.networkCom = self.networkCom
            secondViewController.isParent = self.isParent
            secondViewController.peerID = self.peerID
        }
    }
    @IBAction func backtoFirst(segue:UIStoryboardSegue){//2から1に戻ってきたとき
       
        reConnect()
        networkCom.addObserver(self as NSObject, forKeyPath: "motherID", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "peerNameArray", options: [.new,.old], context: nil)

    }
    
    // A nearby peer has stopped advertising.
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID){
        print("lostpeer")
    }
    
}



