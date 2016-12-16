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
    
    private var ownplayingIndex:Int = 0//自分自身のアイテムのプレイリストインデックス
    
    private var allplayingIndex:Int = 0
    
    private var player:AVAudioPlayer? = nil
  
    private var streamPlayerUrl:NSURL?
    
    private var streamingPlayer:StreamingPlayer!
    
    private var playitemManager:playItemManager!
    
    private var exporter:AudioExporter!
    
    private var myAlert:AlertControlller!

    private var leftPlaylist:Bool = false//まだ再生するべきプレイリストがあるかどうか
    
    private var sequenceOfPeer:[(title:String,peerID:MCPeerID)] = []
    
    private var songtitleArr:[String] = []
    
    private var showTimer:Timer!
    
    private var showTimerIndex:Int = 0
    
    private var playingState:Bool = false
    
     var isParent:Bool!
    
     var networkCom:NetworkCommunicater!
    
     let nc:NotificationCenter = NotificationCenter.default
    
    @IBOutlet weak var titlelabel: UILabel!

    @IBOutlet weak var titleArt: UIImageView!
    
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var stoppauseBtn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        initialize()
        self.view.backgroundColor = UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0)
        UIApplication.shared.isIdleTimerDisabled = false //スリープしても良い
        // Do any additional setup after loading the view, typically from a nib.
       
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    
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
        SVProgressHUD.setMinimumDismissTimeInterval(0.5)
        networkCom.addObserver(self as NSObject, forKeyPath: "peerNameArray", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "artImage", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "recvStr", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "audioData", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "motherID", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "recvedData", options: [.new,.old], context: nil)
        
        streamingPlayer = StreamingPlayer()
        
        showTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(SecondViewController.showInfoWithtitle(timer:)), userInfo: nil, repeats: true)
       
        showTimer.fire()
        if !isParent!{//子なら親が来るまで操作不能にする
            DispatchQueue.main.async {
                SVProgressHUD.show(withStatus: "待機中")
            }
            
            
        }else{
            networkCom.sendStrtoAll(str: "Imhere")
        }
        
}
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func showInfoWithtitle(timer:Timer){
        if showTimerIndex < self.songtitleArr.count{
            SVProgressHUD.showInfo(withStatus: "プレイリストに追加されました\n\(self.songtitleArr[showTimerIndex])")
            showTimerIndex += 1
        }
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
                if networkCom.peerNameArray.count == 0 && isParent!{
                    DispatchQueue.main.async {
                        self.networkCom.stopsendingAudio()
                        self.myAlert = AlertControlller(titlestr: "接続が切れました", messagestr: "もとの画面に戻ります", okTextstr: "確認", canceltextstr: nil)
                        self.myAlert.addOkAction(okblock: {(alert:UIAlertAction) -> Void in
                            
                            self.segueSecondtofirst()//接続人数が0になったらもとの画面に戻る
                        })
                        self.present(self.myAlert.alert, animated: true, completion: nil)
                        
                }
            }
        }else if key == "motherID"{
                if networkCom.motherID == nil && !isParent{
                    DispatchQueue.main.async {
                        SVProgressHUD.dismiss()
                        self.myAlert = AlertControlller(titlestr: "接続が切れました", messagestr: "もとの画面に戻ります", okTextstr: "確認", canceltextstr: nil)
                        self.myAlert.addOkAction(okblock: {(alert:UIAlertAction) -> Void in
                            self.segueSecondtofirst()//接続人数が0になったらもとの画面に戻る
                        })
                        self.present(self.myAlert.alert, animated: true, completion: nil)
                        
                    }

                }
        }else if key == "artImage"{
                DispatchQueue.main.async {
                    self.titleArt.image = self.networkCom.artImage
                    self.view.setNeedsDisplay()
                }
                
        }else if key == "recvStr"{
                doSomething(withStr: networkCom.recvStr!)
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
                        print("動いてるよん")
                        leftPlaylist = checkListOfSong(num: allplayingIndex + 1)
                        if leftPlaylist{
                            allplayingIndex += 1
                            print(sequenceOfPeer[allplayingIndex].peerID.displayName)
                            networkCom.sendStrtoOne(str: "yourturn", peer: sequenceOfPeer[allplayingIndex].peerID)

                        }
                    }

                }else{//子なら受け入れる
                    songtitleArr.removeAll()
                    songtitleArr.append(contentsOf: recvedArr as! [String])
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
                            self.playingState = (self.player?.isPlaying)!
                            self.toggleBtnImage()
                        }
                        if !self.isParent!{
                            self.allplayingIndex = 1 //自動で次にいくフラグを強制的に立てる
                        }
                        self.exporter.removeObserver(self as NSObject, forKeyPath: "convertComp")
                        
                    })
                    
                    
                }
            }
        
     }
}
    func doSomething(withStr str:String){
        if str == "play"{
           playingState = playAudio()
           toggleBtnImage()
        }else if str == "pause"{
           playingState = pauseAudio()
           toggleBtnImage()
        }else if str == "stop"{
            stopAudioStream()
            resetStream()
            
        }else if str == "noimage"{
            DispatchQueue.main.async {
                self.titleArt.image = UIImage(named: "no_image.png")
            }
        }else if str == "yourturn"{
            playitemManager.movePlayItem(toIndex: ownplayingIndex)
            playandStreamingSong()
            
        }else if str == "end"{
            //親なら次の曲をやるように司令をだす
            sendOrderWhenendOfPlay()
            
            
        }else if str == "Imhere"{
            print("ので")
            SVProgressHUD.dismiss()
        }else{
            DispatchQueue.main.async {//タイトルの文字列が送られてきたと判断
                if !self.isParent!{
                    self.allplayingIndex = 1 //自動で次にいくフラグを強制的に立てる
                }
                self.titlelabel.text = str
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

    }
    
    @IBAction func playstopBtnTapped(_ sender: AnyObject) {
        if playingState{
            networkCom.sendStrtoAll(str: "pause")
           playingState = pauseAudio()
            
        }else{
            networkCom.sendStrtoAll(str: "play")
           playingState = playAudio()
        }
        toggleBtnImage()
    }
    func toggleBtnImage(){
        let image1 = UIImage(named: "play_button.png")
        let image2 = UIImage(named: "stop_button.png")
        if playingState{
            DispatchQueue.main.async {
                self.stoppauseBtn.setImage(image2, for: UIControlState.normal)
                SVProgressHUD.show(image1, status: "再生")
            }
        }else{
            DispatchQueue.main.async {
                 self.stoppauseBtn.setImage(image1, for: UIControlState.normal)
                SVProgressHUD.show(image2, status: "停止")
            }
        }
    }
    @IBAction func selectBtnTapped(_ sender: AnyObject) {
       
        let picker = MPMediaPickerController()
        picker.delegate = self
        picker.allowsPickingMultipleItems = true
        present(picker,animated: true,completion: nil)
        
    }
    
    @IBAction func returnBtnTapped(_ sender: Any) {
        myAlert = AlertControlller(titlestr: "戻りますか？", messagestr: "相手との接続が切れます", okTextstr: "戻る", canceltextstr: "キャンセル")
        myAlert.addOkAction(okblock: {(action:UIAlertAction)-> Void in
            self.segueSecondtofirst()
        })
        myAlert.addCancelAction(cancelblock: nil)
        present(myAlert.alert, animated: true, completion: nil)
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
    func playAudio() -> Bool{
        var result:Bool = false
        if  player != nil{
            player?.play()
            result = (player?.isPlaying)!
        }else if streamingPlayer != nil{
           result = streamingPlayer.play()
        }
        return result
    }
    func pauseAudio() -> Bool{
        var result:Bool = false
        if  player != nil{
            player?.pause()
            print( "いま何秒\(player?.currentTime ?? 0)")
            result = (player?.isPlaying)!
        }else if streamingPlayer != nil{
            result = streamingPlayer.pause()
        }
        
        return result
    }
    func resetStream(){
        streamingPlayer = nil
        streamingPlayer = StreamingPlayer()
        streamingPlayer.start()
    }
    func stopAudioStream(){
        if streamingPlayer != nil{
           playingState = streamingPlayer.stop()
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
        
        performSegue(withIdentifier: "2to1", sender: nil)
        
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "2to1" {
           removeOb()
            networkCom.disconnectPeer()//戻るので切断
            showTimer.invalidate()
            
        let firstViewController:FirstViewController = segue.destination as! FirstViewController
           firstViewController.networkCom = self.networkCom
            
           
                networkCom.stopsendingAudio()
                deleteFile()
               playingState = pauseAudio()
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
                
            }
            var sendArr:[String] = []//新しく追加された曲のタイトル
            for item in mediaItemCollection.items{
                sendArr.append(item.title!)
            }
            
            if playitemManager == nil{//最初選んだとき
                playitemManager = playItemManager(withItems: mediaItemCollection)//最初なので初期化
                songtitleArr.append(contentsOf: sendArr)
                leftPlaylist = true
                playandStreamingSong()
            }else{
                playitemManager.addPlayItems(mediaItems: mediaItemCollection)
                playitemManager.movePlayItem(toIndex: ownplayingIndex)
                songtitleArr.append(contentsOf: sendArr)
                if !leftPlaylist{
                    //追加されたのでつぎいきまーす.
                
                    leftPlaylist = checkListOfSong(num: allplayingIndex + 1)
                    if leftPlaylist{
                        playandStreamingSong()
                        print("こいつが動いている生")
                        allplayingIndex += 1
                    }
                }
                
            }
            let titleData = NSKeyedArchiver.archivedData(withRootObject: songtitleArr)
            networkCom.sendDatatoAll(data: titleData as NSData)
        }else{//子側の処理
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
        
        self.streamPlayerUrl = self.prepareAudioStreaming(item: playitemManager.toPlayItem)
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
    
    
    // MARK: AVAudioplayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool){
        print("終わり")
        let image2 = UIImage(named: "play_button.png")
        DispatchQueue.main.async {
            self.stoppauseBtn.setImage(image2, for: UIControlState.normal)
        }
        self.player?.stop()
        playingState = player.isPlaying
        self.player?.delegate = nil
        self.player = nil
        ownplayingIndex += 1
        playitemManager.movePlayItem(toIndex: ownplayingIndex)
        //基本的にこのメソッドを通るのは自分のライブラリにその曲を持っている場合のみ
        networkCom.sendStrtoAll(str: "pause")
        networkCom.sendStrtoAll(str: "stop")
        networkCom.sendStrtoAll(str: "end")//曲が終わったことを全員にしらせる
        networkCom.stopsendingAudio()
        deleteFile()
        sendOrderWhenendOfPlay()
       
    }
}

