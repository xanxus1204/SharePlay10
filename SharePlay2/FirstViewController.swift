//
//  ViewController.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/09/29.
//  Copyright © 2016年 椛島優. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class FirstViewController: UIViewController,UITableViewDataSource,UITableViewDelegate,MCSessionDelegate,MCNearbyServiceBrowserDelegate,MCNearbyServiceAdvertiserDelegate{
    
    private var peerID: MCPeerID! //セッション作成時に使うID
    
    private var session: MCSession! //セッションを管理するオブジェクト
    
    private var browser: MCNearbyServiceBrowser! //ピアーを探索するときに使うオブジェクト
    private var nearbyAd:MCNearbyServiceAdvertiser! //サービスを公開するときに使うオブジェクト
    
    private var peerNameArray:[String] = []
    
    private var  buttonState:Bool = false //開始ボタンの表示・非表示デフォルトで非表示
    
    private let roomName:String = "abcdefg"
    
    private var roomNum:Int = 0
    
    
    
    
    
    
    @IBOutlet weak var startBtn: UIButton!
    
    
    

    @IBOutlet weak var peerTable: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        //textfieldの終了イベント用delegate
        

        
        
        peerID = MCPeerID(displayName: UIDevice.current.name)//peerIDの設定端末の名前を渡す
        session = MCSession(peer: peerID)//↑で作ったIDを利用してセッションを作成
        
        session.delegate = self //MCSessiondelegateを設定
        
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func createBtnTapped(_ sender: AnyObject) {
        if roomNum == 0 {
            roomNum = createRandomNum() //部屋作成時の４けたの鍵
        }
        let roomNumName = String(describing: roomNum)
        
        let alert = UIAlertController(title: roomNumName, message: "友達に教えてあげよう", preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "閉じる", style: UIAlertActionStyle.default, handler: {(action:UIAlertAction!)-> Void in})
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
        
        
                startServerWithName(name: roomName + roomNumName)
        
    }
    
    @IBAction func searchBtnTapped(_ sender: AnyObject) {
        
        let alert:UIAlertController = UIAlertController(title: "部屋番号を入力", message: "友達に教えてもらおう", preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "決定", style: UIAlertActionStyle.default, handler: {(action:UIAlertAction!)-> Void in
            let textFields:Array<UITextField>? = alert.textFields as Array<UITextField>?
            if textFields != nil{
                let roomNumName = textFields?[0].text
                self.startClientWithName(name: self.roomName + roomNumName!)
            }
        })
        alert.addAction(okAction)
        alert.addTextField(configurationHandler: {(text:UITextField!) -> Void in    text.keyboardType = UIKeyboardType.decimalPad})
        present(alert, animated: true, completion: nil)

        
            }
    @IBAction func startBtnTapped(_ sender: AnyObject) {
            segueFirstToSecond()
    }
      
    
    //MARK: tableview delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return  peerNameArray.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell",for: indexPath)
        let peerName = peerNameArray[indexPath.row]
        cell.textLabel!.text = peerName
    
        return cell

    }
    
    //MARK: MCSessiondelegate
    // 接続状況が変化したとき.
    
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState){
        
        if state == MCSessionState.connected{
            peerNameArray.append(peerID.displayName)
          
        print("接続完了")
            if self.browser != nil{
            self.browser.stopBrowsingForPeers()//探す側の場合接続完了時に探すのをやめる
            DispatchQueue.main.async(execute: {() -> Void in
                self.segueFirstToSecond()})

            }else{
                DispatchQueue.main.async(execute: {() -> Void in
                    self.startBtn.isHidden = false
                    self.peerTable.reloadData()})
            }
        }else if state == MCSessionState.notConnected{
            var num = 0
            for name in peerNameArray {
                
                if name == peerID.displayName{
                    peerNameArray.remove(at: num)
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.peerTable.reloadData()})
                }
                num = num + 1
            }
            print("接続解除")
        }
    }
    
    
    // ピアからデータを受信したとき.
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID){
        
    }
    
    
    // ピアからストリームを受信したとき.
   
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID){
        
    }
    
    
    // リソースからとってくるとき（URL指定とか？).
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress){
        
    }
    
    
    // そのとってくるやつが↑終わったとき
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?){
        
    }
    //MARK: MCNearbyservicebrowserdelegate
    
    //相手を見つけたとき
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?){
        print("見つけた")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 0)
    }
    
    
    // A nearby peer has stopped advertising.
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID){
        
    }

    //MARK: MCNearbyserviceadvitiserdelegate
    //招待されたとき
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Swift.Void){
        print("招待された")
        let alert:UIAlertController = UIAlertController(title: "接続要求", message:"接続する", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: {action in invitationHandler(true,self.session)})
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: {action in invitationHandler(false,self.session)})
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
        

             
    }
    //MARK: 自作関数　主にデータ送受信系
    func startServerWithName(name:String?) -> Swift.Void {
        if name != nil{
            if nearbyAd == nil{
                nearbyAd = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: name!)//サービス用のアドバタイズオブジェクト生成
                nearbyAd.delegate = self//delegate設定
                nearbyAd.startAdvertisingPeer() //サービス公開
            }
           
        }
    }
    func startClientWithName(name:String?) -> Swift.Void {
        if name != nil{
            if browser == nil{
                browser = MCNearbyServiceBrowser(peer: peerID, serviceType: name!) //探索用オブジェクトの生成
                browser.delegate = self //delegateの設定
                browser.startBrowsingForPeers()//探索の開始
            }
           
            
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
    
    //MARK : segue
    
    func segueFirstToSecond(){
        performSegue(withIdentifier: "1to2", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "1to2" {
            // インスタンスの引き継ぎ
            let secondViewController:SecondViewController = segue.destination as! SecondViewController
            secondViewController.session = self.session
            secondViewController.peerNameArray = self.peerNameArray
            
            
        }
    }

}



