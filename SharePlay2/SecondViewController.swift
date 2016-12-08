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

class SecondViewController: UIViewController,MPMediaPickerControllerDelegate,AVAudioPlayerDelegate{
    
    var peerID:MCPeerID!
    
    private var ownplayingIndex:Int = 0
    
    private var allplayingIndex:Int = 0
    
    private var player:AVAudioPlayer? = nil
  
    private var streamPlayerUrl:NSURL?
    
    private var streamingPlayer:StreamingPlayer!
    
    private var playitemManager:playItemManager!
    
    private var exporter:AudioExporter!
    
    private var alert:UIAlertController!
    
    private var leftPlaylist:Bool = false//再生中かどうかも判断可能？ falseなら止まっている
    
    private var sequenceOfPeer:[(title:String,peerID:MCPeerID)] = []
    
    private var songtitleArr:[String] = []
    
     var isParent:Bool!
    
     var networkCom:NetworkCommunicater!
    
     let nc:NotificationCenter = NotificationCenter.default
    
    @IBOutlet weak var titlelabel: UILabel!

    @IBOutlet weak var titleArt: UIImageView!
    
    @IBOutlet weak var restartBtn: UIButton!
    
    @IBOutlet weak var volumeSlider: UISlider!
    override func viewDidLoad() {
        super.viewDidLoad()
        initialize()
        SVProgressHUD.dismiss()
        UIApplication.shared.isIdleTimerDisabled = false //スリープしても良い
        // Do any additional setup after loading the view, typically from a nib.
       
    }
    func initialize(){
        
       
        let accesoryEvent:MPRemoteCommandCenter = MPRemoteCommandCenter.shared()
        accesoryEvent.togglePlayPauseCommand.addTarget(self, action: #selector(SecondViewController.accesoryToggled(event:)))
        UIApplication.shared.beginReceivingRemoteControlEvents()//イヤホンのボタンなどのイベント検知
        nc.addObserver(
            self,
            selector: #selector(SecondViewController.doBeforeTerminate),
            name:NSNotification.Name.UIApplicationWillTerminate,//アプリケーション終了時に実行するメソッドを指定
            object: nil)
        SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.clear) //HUDの表示中入力を受け付けないようにする
        networkCom.addObserver(self as NSObject, forKeyPath: "peerNameArray", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "artImage", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "recvStr", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "audioData", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "motherID", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "recvedData", options: [.new,.old], context: nil)

        streamingPlayer = StreamingPlayer()
        
}
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func accesoryToggled(event:MPRemoteCommandEvent){
        
    }
    func doBeforeTerminate(){
        deleteFile()
        nc.removeObserver(self)
    }
    private func removeOb(){
        
        networkCom.removeObserver(self as NSObject, forKeyPath: "peerNameArray")
        networkCom.removeObserver(self as NSObject, forKeyPath: "artImage")
        networkCom.removeObserver(self as NSObject, forKeyPath: "recvStr")
        networkCom.removeObserver(self as NSObject, forKeyPath: "audioData")
        networkCom.removeObserver(self as NSObject, forKeyPath: "motherID")
        networkCom.removeObserver(self as NSObject, forKeyPath: "recvedData")
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let key = keyPath{
            if key == "peerNameArray"{
                if networkCom.peerNameArray.count == 0{
                    DispatchQueue.main.async {
                        self.segueSecondtofirst()//接続人数が0になったらもとの画面に戻る
                }
            }
        }else if key == "motherID"{
                if networkCom.motherID == nil && !isParent{
                    DispatchQueue.main.async {
                        self.segueSecondtofirst()
                    }
                }
        }else if key == "artImage"{
                DispatchQueue.main.async {
                    self.titleArt.image = self.networkCom.artImage
                    self.view.setNeedsDisplay()
                    SVProgressHUD.show()
                    self.dismissHud(withDelay: 2.0)

                }
                
        }else if key == "recvStr"{
            if networkCom.recvStr == "play"{
                playAudio()
                if !isParent!{
                    allplayingIndex = 1 //自動で次にいくフラグを強制的に立てる
                }
            }else if networkCom.recvStr == "pause"{
                    pauseAudio()
            }else if networkCom.recvStr == "stop"{
                stopAudioStream()
                resetStream()

            }else if networkCom.recvStr == "noimage"{
                DispatchQueue.main.async {
                    
                    self.titleArt.image = UIImage(named: "no_image.png")
                }
                

            }else if networkCom.recvStr == "yourturn"{
                    playitemManager.movePlayItem(toIndex: ownplayingIndex)
                    playandStreamingSong()
            }else if networkCom.recvStr == "end"{
                //親なら次の曲をやるように司令をだす
                sendOrderWhenendOfPlay()
                
                
            }else{
                DispatchQueue.main.async {
                    
                    self.titlelabel.text = self.networkCom.recvStr
                    self.changeVolume(value: self.volumeSlider.value)
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

                }
            }
        }else if key == "audioData"{
                
                streamingPlayer.recvAudio(networkCom.audioData as Data!)
            }else if key == "recvedData"{//タイトルの配列しかない今のところ
                var recvedArr:[Any] =  NSKeyedUnarchiver.unarchiveObject(with: networkCom.recvedData as Data) as! [Any]
               
                if playitemManager == nil{
                    playitemManager = playItemManager()
                }
                if isParent!{//親なら
                    let yourID:MCPeerID = recvedArr[0] as! MCPeerID
                    recvedArr.remove(at: 0)
                    for title in recvedArr{
                        songtitleArr.append(title as! String)
                        sequenceOfPeer.append((title as! String,yourID))
                    }
                    let titleData = NSKeyedArchiver.archivedData(withRootObject: songtitleArr)
                    networkCom.sendDatatoAll(data: titleData as NSData)//全員に今のタイトル配列を送る
                    if !leftPlaylist{//現在再生中の曲がなければ
                    
                        networkCom.sendStrtoOne(str: "yourturn", peer: sequenceOfPeer[allplayingIndex].peerID)
                    }

                }else{//子なら受け入れる
                    songtitleArr = recvedArr as! [String]
                }
                
               
                
            }else if key == "convertComp"{//変換完了した場合の措置
                if change?[.newKey] as! Bool == true{
                   
                    DispatchQueue.main.async(execute: {() -> Void in
                        if self.streamPlayerUrl != nil{
                            if let data = NSData(contentsOf: self.streamPlayerUrl! as URL) {
                                    self.networkCom.sendAudiodata(data: data)
                                }
                        }
                            let audiosession = AVAudioSession.sharedInstance()
                            do{
                                try audiosession.setCategory(AVAudioSessionCategoryPlayback)
                                self.player = try  AVAudioPlayer(contentsOf: self.playitemManager.playUrl!)
                                self.player?.delegate = self
                                self.player?.prepareToPlay()
                                self.player?.volume = self.volumeSlider.value
                            }catch{
                                print("あんまりだあ")
                            }
                            // sessionのアクティブ化
                            do{
                                try audiosession.setActive(true)
                            }catch{
                                fatalError("session有効化失敗")
                            }
                        if self.allplayingIndex != 0{//最初の曲でなければ自動的に再生
                            print("自動で次にいくよ\(self.allplayingIndex)")
                            self.networkCom.sendStrtoAll(str: "play")
                            self.player?.play()
                        }
                        self.exporter.removeObserver(self as NSObject, forKeyPath: "convertComp")
                        SVProgressHUD.dismiss(withDelay: Double(self.networkCom.peerNameArray.count) * 1.0)
                        
                    })
                    
                    
                }
            }
        
     }
}
    @IBAction func restart(_ sender: AnyObject) {
       
        networkCom.sendStrtoAll(str: "play")
        playAudio()
}
    @IBAction func stopBtnTapped(_ sender: AnyObject){
        
            networkCom.sendStrtoAll(str: "pause")
        
        pauseAudio()
    }
    @IBAction func selectBtnTapped(_ sender: AnyObject) {
       
        let picker = MPMediaPickerController()
        picker.delegate = self
        picker.allowsPickingMultipleItems = true
        present(picker,animated: true,completion: nil)
        
    }
    
    @IBAction func returnBtnTapped(_ sender: Any) {
         alert = UIAlertController(title: "戻りますか？", message: "相手との接続が切れます", preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "戻る", style: UIAlertActionStyle.default, handler:{(action:UIAlertAction)-> Void in
                self.segueSecondtofirst()
        })
        let cancelAction = UIAlertAction(title: "キャンセル", style: UIAlertActionStyle.cancel, handler: nil)
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    @IBAction func volumeSliderChanged(_ sender: UISlider) {
        changeVolume(value: sender.value)
    }
        func deleteFile(){
        
        let manager = FileManager()
        do {
            if streamPlayerUrl != nil{
                try manager.removeItem(at: streamPlayerUrl as! URL)
            }
        } catch  {
            print("削除できず")
        }
    }
    //再生、停止などの処理safe
    func playAudio(){
        if  player != nil{
            player?.play()
        }else if streamingPlayer != nil{
            streamingPlayer.play()
        }
        
    }
    func pauseAudio(){
        if  player != nil{
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
        if player != nil{
            player?.volume = value
        }else if streamingPlayer != nil{
            streamingPlayer.changeVolume(value)
        }
    }
    //MARK: -Segue
    func segueSecondtofirst(){
        removeOb()
        performSegue(withIdentifier: "2to1", sender: nil)
        
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "2to1" {
           
            DispatchQueue.main.async {
                
                self.networkCom.disconnectPeer()//戻るので切断
            }
        let firstViewController:FirstViewController = segue.destination as! FirstViewController
           firstViewController.networkCom = self.networkCom
            
           
                networkCom.stopsendingAudio()
                deleteFile()
                pauseAudio()
            UIApplication.shared.endReceivingRemoteControlEvents()
            stopAudioStream()
        }
    }
       //MARK: - MPMediapicker
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        ///親側と子側で分岐
        if isParent!{
            for item in mediaItemCollection.items{
                sequenceOfPeer.append((item.title!,peerID))
                songtitleArr.append(item.title!)
            }
            if playitemManager == nil{//最初選んだとき
                playitemManager = playItemManager(withItems: mediaItemCollection)//最初なので初期化
                leftPlaylist = true
                playandStreamingSong()
            }else{
                playitemManager.addPlayItems(mediaItems: mediaItemCollection)
                if !leftPlaylist{
                    //追加されたのでつぎいきまーす.
                
                    leftPlaylist = checkListOfSong(num: allplayingIndex + 1)
                    if leftPlaylist{
                        playandStreamingSong()
                        allplayingIndex += 1
                    }
                }
            }

        }else{
            //子側の処理
             var sendArr:[Any] = [self.peerID]//配列の人マス目に自分のIDを格納
            for item in mediaItemCollection.items{
                sendArr.append(item.title!)
            }
            let titleData = NSKeyedArchiver.archivedData(withRootObject: sendArr)
            networkCom.sendDatatoOne(data: titleData as NSData, recvpeer: networkCom.motherID)
            if playitemManager == nil{
                playitemManager = playItemManager(withItems: mediaItemCollection)//最初なので初期化
                
            }else{
                playitemManager.addPlayItems(mediaItems: mediaItemCollection)
                playitemManager.movePlayItem(toIndex: ownplayingIndex)//ある種の初期化作業
            }
        }
                    mediaPicker.dismiss(animated: true, completion: nil)
    }
    func playandStreamingSong(){
        DispatchQueue.main.async {
            self.titlelabel.text = self.playitemManager.itemProperty.musicTitle
        }
        self.networkCom.sendStrtoAll(str: "stop")
        
        if  let artwork = playitemManager.itemProperty.albumArtWork{
            networkCom.artImage = artwork
            DispatchQueue.main.async {
                 self.titleArt.image = self.networkCom.artImage
            }
           
            networkCom.sendImage(image: networkCom.artImage)
            
        }else{
            DispatchQueue.main.async {
                self.titleArt.image = UIImage(named: "no_image.png")
            }
            networkCom.sendStrtoAll(str: "noimage")
        }
        
        self.networkCom.sendStrtoAll(str:playitemManager.itemProperty.musicTitle)
        DispatchQueue.main.async(execute: {() -> Void in
            SVProgressHUD.show(withStatus: "準備中")})
        self.streamPlayerUrl = self.prepareAudioStreaming(item: self.playitemManager.toPlayItem)
    }
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
    func prepareAudioStreaming(item :MPMediaItem) -> NSURL {
        
        exporter = AudioExporter()
        exporter.addObserver(self as NSObject, forKeyPath: "convertComp", options: [.old,.new], context: nil)//変換が終わったかどうかを判断するキー
        let url = exporter.convertItemtoAAC(item: item)
       
              return url
    }
    func checkListOfSong(num:Int) -> Bool{
        if num < songtitleArr.count{
            print("まだあるよ\(num)")
            print(songtitleArr)
            return true
        }else{
            print("もうないよ\(num)")
            return false
        }
    }
    func sendOrderWhenendOfPlay(){
        if isParent!{//親の場合
            leftPlaylist = checkListOfSong(num: allplayingIndex + 1)
            if leftPlaylist{//次の曲があった場合のみ
                allplayingIndex += 1
                if sequenceOfPeer[allplayingIndex].peerID == peerID{//次の順番が自分なら
                    playandStreamingSong()
                    print("またわたしかよ")
                }else{// 次の順番のやつに対して送る
                    print("つぎはお前だ!")
                    networkCom.sendStrtoOne(str: "yourturn", peer: sequenceOfPeer[allplayingIndex].peerID)
                }
            }
        }
    }
    func dismissHud(withDelay delay:Double){
        DispatchQueue.global().async {
            Thread.sleep(forTimeInterval: delay)
            SVProgressHUD.dismiss()
        }
        
    }
    // MARK: AVAudioplayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool){
        print("終わり")
        self.player?.stop()
        self.player?.delegate = nil
        self.player = nil
        ownplayingIndex += 1
        print("インデックスをすすめる\(ownplayingIndex)")
        playitemManager.movePlayItem(toIndex: ownplayingIndex)
        //基本的にこのメソッドを通るのは自分のライブラリにその曲を持っている場合のみ
        networkCom.sendStrtoAll(str: "stop")
        networkCom.sendStrtoAll(str: "end")//曲が終わったことを全員にしらせる
        networkCom.stopsendingAudio()
        deleteFile()
        sendOrderWhenendOfPlay()
       
        
    }
}

