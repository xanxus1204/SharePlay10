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

class SecondViewController: UIViewController,MPMediaPickerControllerDelegate,AVAudioPlayerDelegate,UITableViewDelegate,UITableViewDataSource{
    
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
    
    private var showTimer:Timer!
    
    private var showTimerIndex:Int = 0
    
    private var playingState:Bool = false
    
    private var durationOfSong:TimeInterval = 100.0//曲の再生時間
    
    private var sleeptime:TimeInterval = 0.0//再生命令を出すまでの時間
    
    private var doOnceFlag:Bool!
    
    private var myturn:Bool = false
    
    private var convertTime:TimeInterval = 0.0
    
    private var convertBgnTime:TimeInterval = 0.0
    
    private var autoStart:Bool = false
    
    private var songItems:[SongItem] = []
    
     var isParent:Bool!
    
     var networkCom:NetworkCommunicater!
    
     let nc:NotificationCenter = NotificationCenter.default
    
    @IBOutlet weak var titlelabel: UILabel!
    @IBOutlet weak var songTitleTableView: UITableView!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var stoppauseBtn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        initialize()
        self.view.backgroundColor = UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0)
        songTitleTableView.backgroundColor = UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0)
//        UIApplication.shared.isIdleTimerDisabled = false //スリープしても良い
        SVProgressHUD.setMinimumDismissTimeInterval(2.0)
        // Do any additional setup after loading the view, typically from a nib.
       
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    
    }
    func initialize(){
        addAudioSessionObservers()
        songTitleTableView.delegate = self
        let audiosession = AVAudioSession.sharedInstance()
        do {
            try audiosession.setCategory(AVAudioSessionCategoryPlayback, with: AVAudioSessionCategoryOptions.mixWithOthers)//バックグラウンド再生を許可
        } catch  {
        }
        // sessionのアクティブ化
        do {
            try audiosession.setActive(true)
        } catch {
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
        
        showTimer = Timer.scheduledTimer(timeInterval: 1.6, target: self, selector: #selector(SecondViewController.showInfoWithtitle), userInfo: nil, repeats: true)
       
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
              
                sleeptime = leftTime
                SVProgressHUD.show(withStatus: "準備中...")
                let strtime = String(Int(sleeptime * 100))
                
                //基本的にこのメソッドを通るのは自分のライブラリにその曲を持っている場合のみ
                print(strtime)
                networkCom.sendStrtoAll(str: "end" + strtime)//曲が終わったことを全員にしらせる
                myturn = false
                sendOrderWhenendOfPlay()
                doOnceFlag = false
            }
        }
        
        if showTimerIndex < self.songItems.count{
            if self.songItems.count - showTimerIndex > 5 {
                var text = ""
                for num in 0...4{
                    text.append(self.songItems[showTimerIndex+num].songTitle+"\n")
                }
                SVProgressHUD.showInfo(withStatus: "Waiting...\nプレイリストに追加されました\n" + text)
                showTimerIndex += 5
            }else{
                for _ in 1...5{
                    SVProgressHUD.showInfo(withStatus: "Waiting...\nプレイリストに追加されました\n\(self.songItems[showTimerIndex].songTitle)")
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
                let recvedSongTitleData = recvedArr[0] as! Data
                let recvedartImageDatas = recvedArr[1] as! Data
                let recevedSongTitle:[String] = NSKeyedUnarchiver.unarchiveObject(with: recvedSongTitleData) as! [String]
                let recvedartImages:[Data] = NSKeyedUnarchiver.unarchiveObject(with: recvedartImageDatas) as! [Data]
                let yourID:MCPeerID = recvedArr[2] as! MCPeerID
                if isParent!{//親なら
                    networkCom.sendDatatoAll(data:networkCom.recvedData)
                    for num in 0...recevedSongTitle.count-1{
                        let newItem:SongItem = SongItem(image: UIImage(data: recvedartImages[num]), songTitle: recevedSongTitle[num], peerID: yourID)
                        songItems.append(newItem)
                    }
                    if !leftPlaylist{//現在再生中の曲がなければ
                            sendOrderWhenendOfPlay()
                    }
                }else{//子なら受け入れる
                    for num in 0...recevedSongTitle.count-1{
                        let newItem:SongItem = SongItem(image: UIImage(data: recvedartImages[num]), songTitle: recevedSongTitle[num], peerID: yourID)
                        songItems.append(newItem)
                    }
                    
                }
                DispatchQueue.main.async {
                    self.titlelabel.text = self.songItems[self.allplayingIndex-1].songTitle
                    self.songTitleTableView.reloadData()

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
       
        if autoStart == true{
            print("自動で次にいくよ\(self.allplayingIndex)")
            networkCom.sendStrtoAll(str: "play")
            Thread.sleep(forTimeInterval: 0.03)
            player?.play()
            playingState = (player?.isPlaying)!
            toggleBtnImage()
        }else{
            autoStart = true
        }
        DispatchQueue.main.async {
            self.ownplayingIndex += 1
            self.playitemManager.movePlayItem(toIndex: self.ownplayingIndex)
        }
        
        self.exporter.removeObserver(self as NSObject, forKeyPath: "convertComp")
    }
    
    func doSomething(withStr str:String){
        if str == "play"{
           playingState = playAudio()
           toggleBtnImage()
        }else if str == "incre"{
            allplayingIndex += 1
            DispatchQueue.main.async {
                self.titlelabel.text = self.songItems[self.allplayingIndex-1].songTitle
                
            }
        }else if str == "back"{
            skipAudio(tofront: false)
        }else if str == "pause"{
           playingState = pauseAudio()
           toggleBtnImage()
        }else if str == "stop"{
            stopAudioStream()
            resetStream()
            
        }else if str == "next"{
            skipAudio(tofront: true)
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
            autoStart = true
           resetStream()
            DispatchQueue.main.async {//タイトルの文字列が送られてきたと判断
               
                self.titlelabel.text = str
                self.changeVolume(value: self.volumeSlider.value)
                
                
            }
        }

    }
    @IBAction func frontButtontapped(_ sender: Any) {
        networkCom.sendStrtoAll(str: "back")
        skipAudio(tofront: false)
    }
    
    @IBAction func nextButtonTapped(_ sender: Any) {
        networkCom.sendStrtoAll(str: "next")
        skipAudio(tofront: true)
        
    }
    @IBAction func playstopBtnTapped(_ sender: AnyObject) {
        if playingState{
           playingState = pauseAudio()
            if !playingState{
                networkCom.sendStrtoAll(str: "pause")
            }
        }else{
             SVProgressHUD.dismiss()
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
    func skipAudio(tofront front:Bool){
         changeVolume(value: 0)
        if !front{
            
            allplayingIndex -= 2
            if allplayingIndex < 0{
                allplayingIndex = 0
            }
        }
        if  player != nil && myturn{
            if !front{
                ownplayingIndex -= 2
                if ownplayingIndex < 0{
                    ownplayingIndex = 0
                }
                playitemManager.movePlayItem(toIndex: ownplayingIndex)
            }
            if allplayingIndex < self.songItems.count{
               
                playingState = playAudio()
                networkCom.stopsendingAudio()
                player?.currentTime = durationOfSong - 10.0
            }
            
            
        }
    }

    //再生、停止などの処理safe
    func stopAllAudio(){
        if player != nil{
            player?.stop()
        }
        if streamingPlayer != nil{
            streamingPlayer.stop()
        }
        if streamingPlayer46 != nil{
            streamingPlayer46.stop()
        }
    }
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
    //MARK: TableView
     func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songItems.count
    }
     func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SongItemCell", for: indexPath) as? SongItemCell else {
            fatalError("Invalid cell")
        }
        let item = songItems[indexPath.row]
        cell.update(withItem: item)
        
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let indexstr = String(indexPath.row)
        var sendStr = "moveto" + indexstr
        let alert = AlertControlller(titlestr: "曲をスキップしますか？", messagestr: songItems[indexPath.row].songTitle + "\nへ移動します", okTextstr: "OK", canceltextstr: "Cancel")
        alert.addOkAction(okblock:{(action:UIAlertAction!) -> Void in
            
        })
        
        
        
    }
    func AutoScrollto(index:IndexPath){
        songTitleTableView.selectRow(at:index, animated: true, scrollPosition: UITableViewScrollPosition.top)
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
            DispatchQueue.main.async {
                self.networkCom.stopsendingAudio()
                self.deleteFile()
                self.playingState = self.pauseAudio()
                self.stopAllAudio()
            }
        }
    }
       //MARK: - MPMediapicker
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        ///親側と子側で分岐
        showInfoWithtitle()
        var sendArr:[Any] = []
        var sendTitleStr:[String] = []
        var sendImageDatas:[Data] = []
        for item in mediaItemCollection.items{
            sendTitleStr.append(item.title!)
            var sendImageData:Data
            if let artImg = item.artwork{
                sendImageData = UIImageJPEGRepresentation((artImg.image(at: (artImg.bounds.size)))!, 0.01)!//子供の場合圧縮してData型にしとく
            }else{
                sendImageData = Data()
            }
            sendImageDatas.append(sendImageData)
        }
        let sendTitleData = NSKeyedArchiver.archivedData(withRootObject: sendTitleStr)
        let sendImagesData = NSKeyedArchiver.archivedData(withRootObject: sendImageDatas)
        sendArr.append(sendTitleData)
        sendArr.append(sendImagesData)
        sendArr.append(peerID)
        let sendArrData = NSKeyedArchiver.archivedData(withRootObject: sendArr)
            if isParent!{
                var partsOfSongItems:[SongItem] = []
                 for item in mediaItemCollection.items{
                    var songItemImage:UIImage = UIImage()
                    if let artImg = item.artwork{
                        songItemImage = (artImg.image(at: (artImg.bounds.size)))!//親なら画像をそのまま自分のやつに追加
                    }
                    let songitem:SongItem = SongItem(image: songItemImage, songTitle: item.title!, peerID: peerID)
                   partsOfSongItems.append(songitem)
                
                }
                networkCom.sendDatatoAll(data: sendArrData as NSData)
                songItems.append(contentsOf: partsOfSongItems)
                if playitemManager == nil{//最初選んだとき
                    playitemManager = playItemManager(withItems: mediaItemCollection)//最初なので初期化
                    leftPlaylist = true
                    sendOrderWhenendOfPlay()
                }else{
                    playitemManager.addPlayItems(mediaItems: mediaItemCollection)
                    playitemManager.movePlayItem(toIndex: ownplayingIndex)
                    if !leftPlaylist{
                        //追加されたのでつぎいきまーす.
                        sendOrderWhenendOfPlay()
                    }
                }
            }else{
                
                networkCom.sendDatatoOne(data: sendArrData as NSData, recvpeer:networkCom.motherID)
                if playitemManager == nil{
                    playitemManager = playItemManager(withItems: mediaItemCollection)//最初なので初期化
                    
                }else{
                    playitemManager.addPlayItems(mediaItems: mediaItemCollection)
                    playitemManager.movePlayItem(toIndex: ownplayingIndex)//ある種の初期化作業
                }
                
            }
        DispatchQueue.main.async {
            self.titlelabel.text = self.songItems[self.allplayingIndex-1].songTitle
            self.songTitleTableView.reloadData()
            
        }
        mediaPicker.dismiss(animated: true, completion: nil)
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
        if num < songItems.count{
            print("まだあるよ\(num)")
                return true
        }else{
            print("もうないよ\(num)")
            return false
        }
    }
    
    func sendOrderWhenendOfPlay(){
        if isParent!{//親の場合
            var peerofYou:MCPeerID
            if songItems.count == 1 && allplayingIndex == 0{
                leftPlaylist = checkListOfSong(num: 0)
                peerofYou = songItems[0].peerID
            }else{
                leftPlaylist = checkListOfSong(num: allplayingIndex)
            }
            
            if leftPlaylist{//次の曲があった場合のみ
                peerofYou = songItems[allplayingIndex].peerID
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
                    networkCom.sendStrtoAll(str: "incre")
                DispatchQueue.main.async {
                    self.titlelabel.text = self.songItems[self.allplayingIndex-1].songTitle
                }
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

