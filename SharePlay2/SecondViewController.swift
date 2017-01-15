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
    
    private var streamingPlayer46:StreamingPlayer!//二つ目のプレイヤー
    
    private var changePlayer:Bool = true //プレイヤーを交互に使うためのフラグ
    
    private var playitemManager:playItemManager!
    
    private var exporter:AudioExporter!
    
    private var myAlert:AlertControlller!

    private var leftPlaylist:Bool = false//まだ再生するべきプレイリストがあるかどうか
    
    private var sequenceOfPeer:[(title:String,peerID:MCPeerID)] = []
    
    private var songtitleArr:[String] = []
    
    private var showTimer:Timer!
    
    private var showTimerIndex:Int = 0
    
    private var playingState:Bool = false
    
    private var durationOfSong:TimeInterval = 100.0//曲の再生時間
    
    private var sleeptime:TimeInterval = 0.0//再生命令を出すまでの時間
    
    private var doOnceFlag:Bool!
    
    private var myturn:Bool = false
    
    private var convertTime:TimeInterval = 0.0
    
    private var convertBgnTime:TimeInterval = 0.0
    
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
//        UIApplication.shared.isIdleTimerDisabled = false //スリープしても良い
        SVProgressHUD.setMinimumDismissTimeInterval(2.0)
        // Do any additional setup after loading the view, typically from a nib.
       
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    
    }
    func initialize(){
        addAudioSessionObservers()
        let audiosession = AVAudioSession.sharedInstance()
        do {
            try audiosession.setCategory(AVAudioSessionCategoryPlayback, with: AVAudioSessionCategoryOptions.mixWithOthers)//バックグラウンド再生を許可
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
        
        showTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(SecondViewController.showInfoWithtitle), userInfo: nil, repeats: true)
       
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
    func showInfoWithtitle(){//2秒に一回実行される
        if player != nil{
            let leftTime:TimeInterval = durationOfSong - (player?.currentTime)!
            if leftTime < 10.0 && doOnceFlag{
                print("いまだ！\(leftTime)")
                ownplayingIndex += 1
                sleeptime = leftTime
                SVProgressHUD.show(withStatus: "準備中...")
                let strtime = String(Int(sleeptime * 100))
                playitemManager.movePlayItem(toIndex: ownplayingIndex)
                //基本的にこのメソッドを通るのは自分のライブラリにその曲を持っている場合のみ
                print(strtime)
                networkCom.sendStrtoAll(str: "end" + strtime)//曲が終わったことを全員にしらせる
                myturn = false
                sendOrderWhenendOfPlay()
                doOnceFlag = false
            }
        }
        
        if showTimerIndex < self.songtitleArr.count{
            if self.songtitleArr.count - showTimerIndex > 5 {
                var text = ""
                for num in 0...4{
                    text.append(self.songtitleArr[showTimerIndex+num]+"\n")
                }
                SVProgressHUD.showInfo(withStatus: "プレイリストに追加されました\n" + text)
                showTimerIndex += 5
            }else{
                for _ in 1...5{
                    SVProgressHUD.showInfo(withStatus: "プレイリストに追加されました\n\(self.songtitleArr[showTimerIndex])")
                    Thread.sleep(forTimeInterval: 0.5)
                }
                showTimerIndex += 1
            }
        }
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
                        SVProgressHUD.dismiss()
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
                if changePlayer{
                    streamingPlayer.recvAudio(networkCom.audioData as Data!)
                }else{
                    streamingPlayer46.recvAudio(networkCom.audioData as Data!)
                }
                
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
                            sendOrderWhenendOfPlay()
                    }

                }else{//子なら受け入れる
                    songtitleArr.removeAll()
                    songtitleArr.append(contentsOf: recvedArr as! [String])
                }
                
            }else if key == "convertComp"{//変換完了した場合の措置
                if change?[.newKey] as! Bool == true{
                    doWhenConvertCompleted()
                }
            }
        }
}
    func doWhenConvertCompleted(){
         convertTime = CFAbsoluteTimeGetCurrent() - convertBgnTime
        print("こんだけかかった\(convertTime)")
        DispatchQueue.main.async {
            self.networkCom.sendStrtoAll(str: "stop")

            if self.streamPlayerUrl != nil{
                if let data = NSData(contentsOf: self.streamPlayerUrl! as URL) {
                    self.networkCom.sendAudiodata(data: data)
                }
            }
        }
        sendAndSetImg()
        Thread.sleep(forTimeInterval:sleeptime - convertTime)
        let audiosession = AVAudioSession.sharedInstance()
        do {
            try audiosession.setCategory(AVAudioSessionCategoryPlayback, with: AVAudioSessionCategoryOptions.mixWithOthers)//バックグラウンド再生を許可
        }catch{
            // エラー処理
        }
        do {
            try audiosession.setActive(true)
        } catch {
        }
        do{
            player = try  AVAudioPlayer(contentsOf: self.playitemManager.playUrl!)
            player?.delegate = self
            player?.prepareToPlay()
            durationOfSong = (player?.duration)!
            doOnceFlag = true
            player?.volume = self.volumeSlider.value
        }catch{
            print("あんまりだあ")
        }
        // sessionのアクティブ化
        self.changeVolume(value: self.volumeSlider.value)
       
        if allplayingIndex > 1{//最初の曲でなければ自動的に再生
            print("自動で次にいくよ\(self.allplayingIndex)")
            networkCom.sendStrtoAll(str: "play")
            Thread.sleep(forTimeInterval: 0.03)
            player?.play()
            playingState = (player?.isPlaying)!
            toggleBtnImage()
        }
        if !isParent!{
            allplayingIndex = 2 //自動で次にいくフラグを強制的に立てる
        }
        
        self.exporter.removeObserver(self as NSObject, forKeyPath: "convertComp")
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
            
        }else if str == "next"{
            skipAudio()
        }else if str == "noimage"{
            
            DispatchQueue.main.async {
                self.titleArt.image = UIImage(named: "no_image.png")
            }
        }else if str == "yourturn"{
            myturn = true
            playitemManager.movePlayItem(toIndex: ownplayingIndex)
            playandStreamingSong()
            
        }else if str == "noSong"{
            SVProgressHUD.dismiss()
            SVProgressHUD.showInfo(withStatus: "次の曲がありません")
            let image2 = UIImage(named: "play_button.png")
            DispatchQueue.main.async {
                self.stoppauseBtn.setImage(image2, for: UIControlState.normal)
            }
            myturn = false
            changePlayer = !changePlayer
            
        }else if str.hasPrefix("end"){
            //親なら次の曲をやるように司令をだす
            SVProgressHUD.show(withStatus: "準備中...")
            let timestr = str.substring(from:str.index(str.endIndex, offsetBy: -3) )
            let timeDouble = Double(timestr)
            sleeptime = timeDouble! / 100.0
            print(sleeptime)
            myturn = false
            changePlayer = !changePlayer
            sendOrderWhenendOfPlay()
            
            
        }else if str == "Imhere"{
            print("ので")
            SVProgressHUD.dismiss()
        }else{
           resetStream()
            DispatchQueue.main.async {//タイトルの文字列が送られてきたと判断
                if !self.isParent!{
                    self.allplayingIndex = 2 //自動で次にいくフラグを強制的に立てる
                }
                self.titlelabel.text = str
                self.changeVolume(value: self.volumeSlider.value)
                
                
            }
        }

    }
    
    @IBAction func nextButtonTapped(_ sender: Any) {
        networkCom.sendStrtoAll(str: "next")
        skipAudio()
        
    }
    @IBAction func playstopBtnTapped(_ sender: AnyObject) {
        if playingState{
            
            Thread.sleep(forTimeInterval: 0.03)
           playingState = pauseAudio()
            if !playingState{
                networkCom.sendStrtoAll(str: "pause")
            }
            
        }else{
             SVProgressHUD.dismiss()
            
            Thread.sleep(forTimeInterval: 0.03)
           playingState = playAudio()//playが可能だったつまり再生の状態になったら再生を送る。
            if playingState{
                networkCom.sendStrtoAll(str: "play")
            }
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
    func skipAudio(){
        changeVolume(value: 0)
        if  player != nil && myturn{
            playingState = playAudio()
            networkCom.stopsendingAudio()
            player?.currentTime = durationOfSong - 10.0
            
        }
    }
    //再生、停止などの処理safe
    func playAudio() -> Bool{
        var result:Bool = false
        if  player != nil && myturn{
            player?.play()
            result = (player?.isPlaying)!
            print("play自分")
        }else{
            if changePlayer{
                if streamingPlayer != nil{
                    result = streamingPlayer.play()
                    print("play普通")
                }

            }else{
                if streamingPlayer46 != nil{
                    result = streamingPlayer46.play()
                    print("play46")
                }

            }
            
        }
        return result
    }
    func pauseAudio() -> Bool{
        var result:Bool = false
        if  player != nil && myturn{
            player?.pause()
            result = (player?.isPlaying)!
        }else{
            if changePlayer{
                if streamingPlayer != nil{
                    result = streamingPlayer.pause()
                }
                
            }else{
                if streamingPlayer46 != nil{
                    result = streamingPlayer46.pause()
                }
                
            }
            
        }
        return result
    }
    func resetStream(){
        if changePlayer{
            streamingPlayer = nil
            streamingPlayer = StreamingPlayer()
            streamingPlayer.start()
            
        }else{
            streamingPlayer46 = nil
            streamingPlayer46 = StreamingPlayer()
            streamingPlayer46.start()
        }
    }
    func stopAudioStream(){
        if changePlayer{
            if streamingPlayer != nil{
                playingState = streamingPlayer.stop()
            }
        }else{
            if streamingPlayer46 != nil{
                playingState = streamingPlayer46.stop()
            }
        }
        
    }
    func changeVolume(value:Float){
        if player != nil && myturn{
            player?.volume = value
        }else{
            if changePlayer{
                if streamingPlayer != nil{
                    streamingPlayer.changeVolume(value)
                }
            }else{
                if streamingPlayer46 != nil{
                    streamingPlayer46.changeVolume(value)
                }
            }
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
            let center = NotificationCenter.default
            
            // AVAudio Session
            center.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
            //割り込み対応を終了
            
        let firstViewController:FirstViewController = segue.destination as! FirstViewController
           firstViewController.networkCom = self.networkCom
                networkCom.stopsendingAudio()
                deleteFile()
               playingState = pauseAudio()
               player?.stop()

            stopAudioStream()
            }
    }
       //MARK: - MPMediapicker
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        ///親側と子側で分岐
        showInfoWithtitle()
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
                sendOrderWhenendOfPlay()
            }else{
                playitemManager.addPlayItems(mediaItems: mediaItemCollection)
                playitemManager.movePlayItem(toIndex: ownplayingIndex)
                songtitleArr.append(contentsOf: sendArr)
                if !leftPlaylist{
                    //追加されたのでつぎいきまーす.
                    sendOrderWhenendOfPlay()
                }
                
            }
            let titleData = NSKeyedArchiver.archivedData(withRootObject: songtitleArr)
            networkCom.sendDatatoAll(data: titleData as NSData)
        }else{//子側の処理
            if playitemManager == nil{
                playitemManager = playItemManager(withItems: mediaItemCollection)//最初なので初期化
                
            }else{
                playitemManager.addPlayItems(mediaItems: mediaItemCollection)
                playitemManager.movePlayItem(toIndex: ownplayingIndex)//ある種の初期化作業
            }
             var sendArr:[Any] = [self.peerID]//配列の人マス目に自分のIDを格納
            for item in mediaItemCollection.items{
                sendArr.append(item.title!)
            }
            let titleData = NSKeyedArchiver.archivedData(withRootObject: sendArr)
            networkCom.sendDatatoOne(data: titleData as NSData, recvpeer: networkCom.motherID)
           
        }
                    mediaPicker.dismiss(animated: true, completion: nil)
    }
    func sendAndSetImg(){
        DispatchQueue.main.async {
            self.titlelabel.text = self.playitemManager.itemProperty.musicTitle
        }
         self.networkCom.sendStrtoAll(str:playitemManager.itemProperty.musicTitle)
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
        

    }
    func playandStreamingSong(){
        deleteFile()//前生成したファイルを削除
        convertBgnTime = CFAbsoluteTimeGetCurrent()
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
            var peerofYou:MCPeerID
            if songtitleArr.count == 1 && allplayingIndex == 0{
                leftPlaylist = checkListOfSong(num: 0)
                peerofYou = sequenceOfPeer[0].peerID
            }else{
                leftPlaylist = checkListOfSong(num: allplayingIndex)
            }
            
            if leftPlaylist{//次の曲があった場合のみ
                peerofYou = sequenceOfPeer[allplayingIndex].peerID
                if peerofYou == peerID{//次の順番が自分なら
                    myturn = true
                    playandStreamingSong()
                    
                    print("またわたしかよ")
                }else{// 次の順番のやつに対して送る
                    var thereisPeer:Bool = false
                    for  peer in networkCom.peerStates {
                        if peer.peerID == peerofYou{
                            thereisPeer = true
                        }
                    }
                    if thereisPeer{
                        print("つぎはお前だ!")
                        networkCom.sendStrtoOne(str: "yourturn", peer: peerofYou)
                    }else{
                        sendOrderWhenendOfPlay()
                    }
                    
                }
                    allplayingIndex += 1
            }else{
                SVProgressHUD.dismiss()
                SVProgressHUD.showInfo(withStatus: "次の曲がありません")
                networkCom.sendStrtoAll(str: "noSong")
                myturn = false
                changePlayer = !changePlayer
            }
        }
    }
    
    
    // MARK: AVAudioplayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool){
        print("終わり")
        SVProgressHUD.dismiss()
        let image2 = UIImage(named: "play_button.png")
        DispatchQueue.main.async {
            self.stoppauseBtn.setImage(image2, for: UIControlState.normal)
        }
        playingState = player.isPlaying
       
       
       
    }
    // MARK: AVAudiosession Interruption
    func addAudioSessionObservers() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(SecondViewController.handleInterruption(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
    }
    /// Interruption : 電話による割り込み
    func handleInterruption(_ notification: Notification) {
        
        let interruptionTypeObj = (notification as NSNotification).userInfo![AVAudioSessionInterruptionTypeKey] as! NSNumber
        if let interruptionType = AVAudioSessionInterruptionType(rawValue:
            interruptionTypeObj.uintValue) {
            
            switch interruptionType {
            case .began:
                print("Interruption Begin")
               
                                break
            case .ended:
                break
                
            }
        }
        
    }
    
   }

