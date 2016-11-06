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

class SecondViewController: UIViewController,MCSessionDelegate,MPMediaPickerControllerDelegate {
    
   private let bufferSize = 32768
    
    var session:MCSession!
    
    var peerNameArray:[String] = []
    
    var isParent:Bool?
    
   private var toPlayItem:MPMediaItem!
    
   private var player:AVAudioPlayer? = nil
  
    private var streamPlayerUrl:NSURL?
    
    private var streamingPlayer:StreamingPlayer!
    
    private var sendQueue:[NSData] = []
    
    private var recvDataArray:NSMutableArray!
    
    private var artImage:UIImage!
    
    private var ownPlayerUrl:NSURL?
    
    private var musicName:String?
    
    private var tempData:NSMutableData!//ファイルの容量が大きいものを受信する時用
    
    private var timer:Timer!
    
    private var delayTime:Double!
    
    var filePath:String?
    
    private var fileName:String!
    
    var fileOpenFlag:Bool!
    
    var documentInteraction:UIDocumentInteractionController!
    enum dataType:Int {//送信するデータのタイプ
        case isString = 1
        case isImage = 2
        case isAudio = 3
        case isFile = 4
    }
    @IBOutlet weak var titlelabel: UILabel!

    @IBOutlet weak var titleArt: UIImageView!
    
    @IBOutlet weak var selectBtn: UIButton!
    
    @IBOutlet weak var restartBtn: UIButton!
    
    @IBOutlet weak var volumeSlider: UISlider!
    override func viewDidLoad() {
        super.viewDidLoad()
        initialize()
        // Do any additional setup after loading the view, typically from a nib.
       
    }
    func initialize(){
        session.delegate = self //MCSessionデリゲートの設定
        let nc:NotificationCenter = NotificationCenter.default
        nc.addObserver(self, selector:#selector(SecondViewController.finishedConvert(notification:)), name: NSNotification.Name(rawValue: "finishConvert"), object: nil)//変換完了の通知を受け取る準備
        nc.addObserver(
            self,
            selector: #selector(SecondViewController.deleteFile),
            name:NSNotification.Name.UIApplicationWillTerminate,//アプリケーション終了時に実行するメソッドを指定
            object: nil)
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
        recvDataArray = NSMutableArray()
        tempData = NSMutableData()
        
        if !isParent!{//部屋を作成した側の場合
            selectBtn.isHidden = true
        }
        delayTime = 0.00001
    
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    @IBAction func restart(_ sender: AnyObject) {
       playAudio()
        if isParent!{
            sendStr(str: "play")
        }
}
    @IBAction func stopBtnTapped(_ sender: AnyObject){
       pauseAudio()
        if isParent!{
            sendStr(str: "pause")
        }
    }
    @IBAction func selectBtnTapped(_ sender: AnyObject) {
       
        let picker = MPMediaPickerController()
        picker.delegate = self
        picker.allowsPickingMultipleItems = false
        present(picker,animated: true,completion: nil)
        
    }
   
    @IBAction func returnBtn(_ sender: AnyObject) {
        stopAudioStream()
        if timer != nil {
            timer.invalidate()
        }
       
        session.disconnect()
        session.delegate = nil
        session = nil
        deleteFile()

    }
    
    @IBAction func fileSelectTapped(_ sender: Any) {
       
}
    
    @IBAction func volumeSliderChanged(_ sender: UISlider) {
        changeVolume(value: sender.value * sender.value)
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
            DispatchQueue.main.async {
                self.segueSecondtofirst()
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
            let contents = recvDataArray[2] as! Data
            if type  == dataType.isAudio.rawValue{//中身がオーディオデータのとき
                   self.streamingPlayer.recvAudio(contents)
                
            }else if type == dataType.isString.rawValue{//中身が文字列のとき
                let str = NSString(data: contents, encoding: String.Encoding.utf8.rawValue) as String?
                if str == "pause"{
                    print("recvpause")
                         pauseAudio()
                    
                }else if str == "play"{
                    playAudio()
                }else if str == "noimage"{
                    DispatchQueue.main.async {
                        self.titleArt.image = UIImage(named: "no_image.png")
                    }
                }else{//曲のタイトルだと考えて設定
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.fileName = str
                        self.titlelabel.text = str
                        self.stopAudioStream()
                        self.resetStream()

                    })
                }
            }else if type == dataType.isImage.rawValue{//中身が画像のとき
                let isFin = recvDataArray[1] as! Int
                if isFin == 0 {
                    tempData.append(contents)
                    print("画像のデータサイズ",tempData.length)
                    DispatchQueue.main.async(execute: {() -> Void in  self.titleArt.image = UIImage(data: self.tempData as Data)
                        self.tempData = NSMutableData()
                        
                    })
                }else{
                    tempData.append(contents)
                  
                }
                
            }else if type == dataType.isFile.rawValue{
                let isFin = recvDataArray[1] as! Int
                if isFin == 0 {
                    tempData.append(contents)
                    let docDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)[0]
                    let manager = FileManager.default
                    let path = docDir + "/" + fileName
                    manager.createFile(atPath: path, contents: tempData as Data?, attributes: nil)
                    DispatchQueue.main.async {
                        self.documentInteraction = UIDocumentInteractionController(url: URL(fileURLWithPath:path))
                        
                        if !self.documentInteraction.presentOpenInMenu(from: self.view.frame, in: self.view, animated: true) {
                            // 送信できるアプリが見つからなかった時の処理
                            let alert = UIAlertController(title: "送信失敗", message: "ファイルを送れるアプリが見つかりません", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                            
                        }

                    }
                                         self.tempData = NSMutableData()
                        
                    
                }else{
                    tempData.append(contents)
                    
                }

            }
        }
    }
       // MARK: 自作関数　データ送信
    func sendDataInterval(){
        if sendQueue.count > 0{
            do {
                try session.send(sendQueue[0] as Data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                sendQueue.remove(at: 0)
                
            }catch{
                
                print("Send Failed")
            }

        }
        
    }
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
        let sendDataArray = NSMutableArray()
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
                if option == dataType.isAudio{
                    sendQueue.append(sendingData as NSData)
                }else{
                    do {
                        try session.send(sendingData, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                        
                    }catch{
                        
                        print("Send Failed")
                    }
                }
            }else{
                data.getBytes(&buf, range: NSMakeRange(index,splitDataSize))
                tempData = NSMutableData(bytes: buf,length:splitDataSize)
                sendDataArray[2] = tempData
                let sendingData = NSKeyedArchiver.archivedData(withRootObject: sendDataArray)
                if option == dataType.isAudio{
                    sendQueue.append(sendingData as NSData)
                }else{
                    do {
                        try session.send(sendingData, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                        
                    }catch{
                        
                        print("Send Failed")
                    }
                }
            }
            index=index+bufferSize
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
    //再生、停止などの処理safe
    func playAudio(){
        if isParent! && player != nil{
            player?.play()
        }else if streamingPlayer != nil{
            streamingPlayer.play()
        }
        
    }
    func pauseAudio(){
        if isParent! && player != nil{
            player?.pause()
        }else if streamingPlayer != nil{
            streamingPlayer.pause()
        }

    }
    func resetStream(){
        streamingPlayer = nil
        streamingPlayer = StreamingPlayer()
        streamingPlayer.start()
        
    }
    func stopAudioStream(){
        if streamingPlayer != nil{
            streamingPlayer.stop()
        }
    }
    func changeVolume(value:Float){
        if player != nil && isParent!{
            player?.volume = value
        }else if streamingPlayer != nil{
            streamingPlayer.changeVolume(value)
        }
    }
    //MARK: -Segue
    func segueSecondtofirst(){
        stopAudioStream()
        
        if self.timer != nil{
            self.timer.invalidate()
        }
        deleteFile()
        performSegue(withIdentifier: "2to1", sender: nil)
        
    }
    @IBAction func backtoSecond(segue:UIStoryboardSegue){//3から2に戻ってきたとき
        print("戻ってきた3から２へ")
        let docDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)[0]
        if fileOpenFlag != nil{
            if fileOpenFlag!{
                DispatchQueue.main.async {
                    self.documentInteraction = UIDocumentInteractionController(url: URL(fileURLWithPath:docDir + "/" + self.filePath!))
                    if !self.documentInteraction.presentOpenInMenu(from: self.view.frame, in: self.view, animated: true)
                    {
                        // 送信できるアプリが見つからなかった時の処理
                        let alert = UIAlertController(title: "送信失敗", message: "ファイルを送れるアプリが見つかりません", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }else{
                sendStr(str: filePath!)//この時点ではファイルの名前のみ
                let data = NSData(contentsOfFile: docDir + "/" + filePath!)
                sendData(data: data!, option: dataType.isFile)
            }
            fileOpenFlag = nil
        }
        
      
       
       
    }
    //MARK: - MPMediapicker
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        if self.timer != nil{
            timer.invalidate()
            self.sendQueue.removeAll()
            
        }
        self.deleteFile()
        self.toPlayItem = mediaItemCollection.items[0]
        self.musicName =  self.toPlayItem.value(forProperty: MPMediaItemPropertyTitle) as? String
        self.titlelabel.text = self.musicName
        if toPlayItem.value(forProperty: MPMediaItemPropertyArtwork) != nil{
            let artwork:MPMediaItemArtwork  = (self.toPlayItem.value(forProperty: MPMediaItemPropertyArtwork) as? MPMediaItemArtwork)!
            
            self.artImage = artwork.image(at: artwork.bounds.size)
            self.titleArt.image = self.artImage

        }else{
            self.artImage = nil
            self.titleArt.image = UIImage(named: "no_image.png")
            print("Noimaage")
        }
        if self.artImage != nil{
            
            let imageData = UIImagePNGRepresentation(self.artImage)
            let image = UIImage(data: imageData!)
            
            self.titleArt.image = image
            if imageData != nil{
                self.sendData(data: imageData! as NSData , option: dataType.isImage)
            }
        }else{
            self.sendStr(str: "noimage")
            
        }
        let musicNameData = self.musicName?.data (using:String.Encoding.utf8)
        if musicNameData != nil{
            self.sendData(data: musicNameData! as NSData, option: dataType.isString)
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
            
            self.sendQueue.removeAll()
            //この辺はオーディオデータの送信に関わる部分
           
            if self.streamPlayerUrl != nil{
                if let data = NSData(contentsOf: self.streamPlayerUrl! as URL) {
                    
                    self.sendData(data: data, option: dataType.isAudio)
                }
            }
            for _ in 0..<5{
                self.sendDataInterval()//３パケットだけさっと送る
            }
            if self.timer != nil{
                self.timer.invalidate()
            }
           
            self.timer = Timer.scheduledTimer(timeInterval: self.delayTime, target: self, selector: #selector(self.sendDataInterval), userInfo: nil, repeats: true)//データを送り始めるよーん
            self.timer.fire()
            
            if self.isParent!{
                let audiosession = AVAudioSession.sharedInstance()
                do{
                    try audiosession.setCategory(AVAudioSessionCategoryPlayback)
                    self.player = try  AVAudioPlayer(contentsOf: self.ownPlayerUrl as! URL)
                    self.player?.prepareToPlay()
                    self.player?.volume = self.volumeSlider.value * self.volumeSlider.value
                    
                }catch{
                    print("あんまりだあ")
                }
                
            }
            SVProgressHUD.dismiss(withDelay: Double(self.peerNameArray.count) * 2.0)
            
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


