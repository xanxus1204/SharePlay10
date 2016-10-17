//
//  SecondViewController.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/09/29.
//  Copyright © 2016年 椛島優. All rights reserved.
//コメント

import UIKit
import MultipeerConnectivity
import MediaPlayer

// first commit


class SecondViewController: UIViewController,MCSessionDelegate,MPMediaPickerControllerDelegate {
    
   private let bufferSize = 3000000
    
    var session:MCSession!
    
    var peerNameArray:[String] = []
    
    private var recvData:Data!
    
   private var toPlayItem:MPMediaItem!
    
   private var player:AVAudioPlayer!
  
    private var playerUrl:NSURL?
    
    private var streamingPlayer:StreamingPlayer!
    
    private var sendDataArray:NSMutableArray!
    
    private var recvDataArray:NSMutableArray!
    
    private var artImage:UIImage!
    
    private var musicName:String?
    enum dataType:Int {
        case isString = 1
        case isImage = 2
        case isAudio = 3
    }
    @IBOutlet weak var titlelabel: UILabel!

    @IBOutlet weak var titleArt: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        initialize()
        // Do any additional setup after loading the view, typically from a nib.
       
    }
    func initialize(){
        session.delegate = self //MCSessionデリゲートの設定
        recvData = Data()  // 受信データオブジェクトの初期化
        self.streamingPlayer = StreamingPlayer()

        let nc:NotificationCenter = NotificationCenter.default
        nc.addObserver(self, selector:#selector(SecondViewController.finishedConvert(notification:)), name: NSNotification.Name(rawValue: "finishConvert"), object: nil)//変換完了の通知を受け取る準備
        SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.clear) //HUDの表示中入力を受け付けないようにする
        let audiosession = AVAudioSession.sharedInstance()
        do {
            try audiosession.setCategory(AVAudioSessionCategoryPlayback)//バックグラウンド再生を許可
        } catch  {
            // エラー処理
            fatalError("カテゴリ設定失敗")
        }
        
        // sessionのアクティブ化
        do {
            try audiosession.setActive(true)
        } catch {
            // audio session有効化失敗時の処理
            // (ここではエラーとして停止している）
            fatalError("session有効化失敗")
        }
        sendDataArray = NSMutableArray()
        recvDataArray = NSMutableArray()

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func stopBtnTapped(_ sender: AnyObject) {
     let orderData = "stop".data(using: String.Encoding.utf8)
        sendData(data: orderData! as NSData, option: dataType.isString)
    }
    @IBAction func selectBtnTapped(_ sender: AnyObject) {
       
        let picker = MPMediaPickerController()
        picker.delegate = self
        picker.allowsPickingMultipleItems = false
        present(picker,animated: true,completion: nil)
    }
    @IBAction func playBtnTapped(_ sender: AnyObject) {
        print(playerUrl!)
        
        if playerUrl != nil{

                    if let data = NSData(contentsOf: self.playerUrl! as URL) {
                        sendData(data: data, option: dataType.isAudio)
                    }
            
            
        }
    }
   
    //MARK : MCSessiondelegate
    
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState){
        
        if state == MCSessionState.connected{
            print("接続完了")
            peerNameArray.append(peerID.displayName)
        }else if state == MCSessionState.notConnected{
            var num = 0
            for name in peerNameArray {
                
                if name == peerID.displayName{
                    peerNameArray.remove(at: num)
                    num = num + 1
                }
            }

            print("接続解除")
        }
    }

   
    
    // ピアからデータを受信したとき.
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID){
        
        recvDataArray = NSKeyedUnarchiver.unarchiveObject(with: data) as! NSMutableArray!
        if recvDataArray != nil{
            let type = recvDataArray[0] as! Int
            let contents = recvDataArray[1] as! Data
            if type  == dataType.isAudio.rawValue{//中身がオーディオデータのとき
                
                streamingPlayer.recvAudio(contents)
            }else if type == dataType.isString.rawValue{//中身が文字列のとき
                let str = NSString(data: contents, encoding: String.Encoding.utf8.rawValue) as String?
                if str == "stop"{
                    
                DispatchQueue.main.async(execute: {() -> Void in
               
                    self.streamingPlayer.stop()
                    self.streamingPlayer = StreamingPlayer()
                    self.streamingPlayer.start()
                })
                }else{
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.titlelabel.text = str
                        self.streamingPlayer.stop()
                        self.streamingPlayer = StreamingPlayer()
                        self.streamingPlayer.start()

                    })

                }
            }else if type == dataType.isImage.rawValue{//中身が画像のとき
                DispatchQueue.main.async(execute: {() -> Void in  self.titleArt.image = UIImage(data: contents)
                })
                            }
        }
       
        
       
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
    // MARK : 自作関数　データ送信
    func sendData(data:NSData,option:dataType) -> () {
        var splitDataSize = bufferSize
        //var indexofData = 0
        var buf = Array<Int8>(repeating: 0, count: bufferSize)
        //var error: NSError!
        var tempData = NSMutableData()
        var index = 0
        sendDataArray[0] = option.rawValue
        while index < data.length {
            
            if (index >= data.length-bufferSize) || (data.length < bufferSize) {
                splitDataSize = data.length - index
                buf = Array<Int8>(repeating: 0, count: splitDataSize)
                
                data.getBytes(&buf, range: NSMakeRange(index,splitDataSize))
                tempData = NSMutableData(bytes: buf, length: splitDataSize)
                sendDataArray[1] = tempData
                let sendingData = NSKeyedArchiver.archivedData(withRootObject: sendDataArray)
                do {
                    try session.send(sendingData as Data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                    let finish = "end"
                    let finData = finish.data(using: String.Encoding.utf8)
                    try session.send(finData! as Data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                    
                }catch{
                    
                    print("Send Failed")
                }
                
            }else{
                data.getBytes(&buf, range: NSMakeRange(index,splitDataSize))
                tempData = NSMutableData(bytes: buf,length:splitDataSize)
                sendDataArray[1] = tempData
                let sendingData = NSKeyedArchiver.archivedData(withRootObject: sendDataArray)
                do{
                    try session.send(sendingData as Data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                }catch{
                    print("Failed")
                    
                }
            }
            index=index+bufferSize
        }
        
    }
    //MARK : - MPMediapicker
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        
        self.toPlayItem = mediaItemCollection.items[0]
        self.musicName =  self.toPlayItem.value(forProperty: MPMediaItemPropertyTitle) as? String
        self.titlelabel.text = self.musicName
        if toPlayItem.value(forProperty: MPMediaItemPropertyArtwork) != nil{
            let artwork:MPMediaItemArtwork  = (self.toPlayItem.value(forProperty: MPMediaItemPropertyArtwork) as? MPMediaItemArtwork)!
            
            self.artImage = artwork.image(at: artwork.bounds.size)
            self.titleArt.image = self.artImage

        }
       
        
                        mediaPicker .dismiss(animated: true, completion: nil)
         DispatchQueue.main.async(execute: {() -> Void in
                       SVProgressHUD.show(withStatus: "準備中")})
            self.playerUrl = self.prepareAudioStreaming(item: self.toPlayItem)
      

        
        
    }
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
    func prepareAudioStreaming(item :MPMediaItem) -> NSURL {
        
        let exporter:AudioExporter = AudioExporter()
        let url = exporter.convertItemtoAAC(item: item)
      
              return url as NSURL
    }
    
  //MARK : notification
    func finishedConvert(notification:Notification?){
        DispatchQueue.main.async(execute: {() -> Void in
            SVProgressHUD.dismiss()
            let imageData = UIImagePNGRepresentation(self.artImage)
            let image = UIImage(data: imageData!)

            self.titleArt.image = image
            if imageData != nil{
                self.sendData(data: imageData! as NSData , option: dataType.isImage)

            }
            let musicNameData = self.musicName?.data(using:String.Encoding.utf8)
            if musicNameData != nil{
                self.sendData(data: musicNameData! as NSData, option: dataType.isString)
            }
            
            
        })

    }

}


