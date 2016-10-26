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
    
   private let bufferSize = 32768
    
    var session:MCSession!
    
    var peerNameArray:[String] = []
    
    var isParent:Bool?
    
    private var recvData:Data!
    
   private var toPlayItem:MPMediaItem!
    
   private var player:AVAudioPlayer? = nil
  
    private var streamPlayerUrl:NSURL?
    
    private var streamingPlayer:StreamingPlayer!
    
    private var sendDataArray:NSMutableArray!
    
    private var recvDataArray:NSMutableArray!
    
    private var artImage:UIImage!
    
    private var ownPlayerUrl:NSURL?
    
    private var musicName:String?
    
    private var tempData:NSMutableData!//ファイルの容量が大きいものを受信する時用
    
    private var audioDataBuffer:[NSData] = []
    
    private var timer:Timer!
    
    enum dataType:Int {//送信するデータのタイプ
        case isString = 1
        case isImage = 2
        case isAudio = 3
    }
    @IBOutlet weak var titlelabel: UILabel!

    @IBOutlet weak var titleArt: UIImageView!
    
    @IBOutlet weak var selectBtn: UIButton!
    
    @IBOutlet weak var pauseBtn: UIButton!
    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var restartBtn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        initialize()
        // Do any additional setup after loading the view, typically from a nib.
       
    }
    func initialize(){
        session.delegate = self //MCSessionデリゲートの設定
        recvData = Data()  // 受信データオブジェクトの初期化
        self.streamingPlayer = StreamingPlayer()
        player = AVAudioPlayer()
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
        tempData = NSMutableData()
        startBtn.isHidden = true
        
        if !isParent!{//部屋を作成した側の場合
            selectBtn.isHidden = true
        }
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(SecondViewController.deleteFile),
            name:NSNotification.Name.UIApplicationWillTerminate,//アプリケーション終了時に実行するメソッドを指定
            object: nil)
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    @IBAction func restart(_ sender: AnyObject) {
        if isParent!{
            player?.play()
            
            self.sendStr(str: "restart")
            
        }else{
            streamingPlayer.restart()
        }
    }
    @IBAction func stopBtnTapped(_ sender: AnyObject){
        if isParent!{
            player?.pause()
           
            self.sendStr(str: "pause")
            
            
        }else{
            streamingPlayer.pause()
        }
        
    }
    @IBAction func selectBtnTapped(_ sender: AnyObject) {
       
        let picker = MPMediaPickerController()
        picker.delegate = self
        picker.allowsPickingMultipleItems = false
        present(picker,animated: true,completion: nil)
        
    }
    @IBAction func playBtnTapped(_ sender: AnyObject) {
        startBtn.isHidden = true
        restartBtn.isHidden = false
        pauseBtn.isHidden = false
        let audiosession = AVAudioSession.sharedInstance()
        
        do{
            try audiosession.setCategory(AVAudioSessionCategoryPlayback)
            self.player = try  AVAudioPlayer(contentsOf: self.ownPlayerUrl as! URL)
            self.player?.volume = 0.5
            self.player?.play()
        }catch{
            print("あんまりだあ")
        }
        if streamPlayerUrl != nil{
            if let data = NSData(contentsOf: self.streamPlayerUrl! as URL) {
                
                    self.sendData(data: data, option: dataType.isAudio)
                
                
                
            }
        }
       
    }
   
    @IBAction func returnBtn(_ sender: AnyObject) {
        streamingPlayer.stop()
        session.disconnect()
        session.delegate = nil
        session = nil
    }
    //MARK : MCSessiondelegate
    
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState){
        
       if state == MCSessionState.notConnected{
            var num = 0
            for name in peerNameArray {
                
                if name == peerID.displayName{
                    peerNameArray.remove(at: num)
                    num = num + 1
                }
            }
        if peerNameArray.count == 0{
            print("誰も居ないのでもどる")
            segueSecondtofirst()
            
        }

            print("接続解除")
        }
    }
    // ピアからデータを受信したとき.
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID){
        
        recvDataArray = NSKeyedUnarchiver.unarchiveObject(with: data) as! NSMutableArray!
        if recvDataArray != nil{
            let type = recvDataArray[0] as! Int
            let contents = recvDataArray[2] as! Data
            if type  == dataType.isAudio.rawValue{//中身がオーディオデータのとき
                    self.audioDataBuffer.append(contents as NSData)
                    print("audio")
                  
            }else if type == dataType.isString.rawValue{//中身が文字列のとき
                let str = NSString(data: contents, encoding: String.Encoding.utf8.rawValue) as String?
                if str == "pause"{
                    
                            print("pause")
                self.streamingPlayer.pause()
                }else if str == "restart"{
                   
                       self.streamingPlayer.restart()
                    
                }else if str == "start"{
                    
                }else{
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.titlelabel.text = str
                        self.streamingPlayer.stop()
                        self.streamingPlayer = StreamingPlayer()
                        self.streamingPlayer.start()
                        self.audioDataBuffer.removeAll()
                        if self.timer != nil{
                            self.timer.invalidate()
                        }
                        self.timer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.doAudioStream), userInfo: nil, repeats: true)
                        self.timer.fire()


                    })

                }
            }else if type == dataType.isImage.rawValue{//中身が画像のとき
                let isFin = recvDataArray[1] as! Int
                if isFin == 0 {
                    tempData.append(contents)
                    DispatchQueue.main.async(execute: {() -> Void in  self.titleArt.image = UIImage(data: self.tempData as Data)
                        self.tempData = NSMutableData()
                        
                       
                    })
                }else{
                    tempData.append(contents)
                  
                }
                
                            }
        }
       
        
       
    }
       // MARK: 自作関数　データ送信
    func sendStr(str:String) -> Void {
        let orderData = str.data(using: String.Encoding.utf8)
        sendData(data: orderData! as NSData, option: dataType.isString)
    }
    func sendData(data:NSData,option:dataType) -> () {
        
        var splitDataSize = bufferSize
        //var indexofData = 0
        var buf = Array<Int8>(repeating: 0, count: bufferSize)
        //var error: NSError!
        var tempData = NSMutableData()
        var index = 0
        sendDataArray[0] = option.rawValue
        sendDataArray[1] = 1
        while index < data.length {
            
            if (index >= data.length-bufferSize) || (data.length < bufferSize) {
                splitDataSize = data.length - index
                buf = Array<Int8>(repeating: 0, count: splitDataSize)
                
                data.getBytes(&buf, range: NSMakeRange(index,splitDataSize))
                tempData = NSMutableData(bytes: buf, length: splitDataSize)
                sendDataArray[2] = tempData
                sendDataArray[1] = 0//ファイルの終了をお知らせ
                let sendingData = NSKeyedArchiver.archivedData(withRootObject: sendDataArray)
                
                    do {
                        try session.send(sendingData as Data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                        
                    }catch{
                        
                        print("Send Failed")
                    }

                
                
            }else{
                data.getBytes(&buf, range: NSMakeRange(index,splitDataSize))
                tempData = NSMutableData(bytes: buf,length:splitDataSize)
                sendDataArray[2] = tempData
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
    func doAudioStream(tm: Timer){
        
            print("do")
            if (self.audioDataBuffer.count>0){
                for _ in 0..<self.audioDataBuffer.count {
                    self.streamingPlayer.recvAudio(self.audioDataBuffer[0] as Data!)
                    self.audioDataBuffer.remove(at: 0)
                }
                
            }
        
        
    }
    func deleteFile(){
        
        let manager = FileManager()
        do {
            if streamPlayerUrl != nil{
                try manager.removeItem(at: streamPlayerUrl as! URL)
                
            }
            if ownPlayerUrl != nil{
                try manager.removeItem(at: ownPlayerUrl as! URL)
            }
           
        } catch  {
            print("削除できず")
        }
    }
    func segueSecondtofirst(){
        performSegue(withIdentifier: "2to1", sender: nil)
        self.streamingPlayer.stop()
    }
    //MARK: - MPMediapicker
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        self.deleteFile()
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
            self.streamPlayerUrl = self.prepareAudioStreaming(item: self.toPlayItem)
      

        
        
    }
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
    func prepareAudioStreaming(item :MPMediaItem) -> NSURL {
        
        let exporter:AudioExporter = AudioExporter()
        let url = exporter.convertItemtoAAC(item: item)
        
        self.ownPlayerUrl = url[1]
              return url[0] as NSURL
    }
    
  //MARK : notification
    func finishedConvert(notification:Notification?){
        
        DispatchQueue.main.async(execute: {() -> Void in
            
            if self.artImage != nil{
                
                let imageData = UIImagePNGRepresentation(self.artImage)
                let image = UIImage(data: imageData!)
                
                self.titleArt.image = image
                if imageData != nil{
                    self.sendData(data: imageData! as NSData , option: dataType.isImage)
                }
            }
            let musicNameData = self.musicName?.data (using:String.Encoding.utf8)
            if musicNameData != nil{
                self.sendData(data: musicNameData! as NSData, option: dataType.isString)
            }
            self.startBtn.isHidden = false
            SVProgressHUD.dismiss()
            
        })

    }
    // MARK: 使わんやつ
    // ピアからストリームを受信したとき.
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID){
    }
    // リソースからとってくるとき（URL指定とか？).
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress){
    }
    // そのとってくるやつが↑終わったとき
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?){
    }
}


