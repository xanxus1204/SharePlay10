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

class SecondViewController: UIViewController,MPMediaPickerControllerDelegate {
    
   private var toPlayItem:MPMediaItem!
    
   private var player:AVAudioPlayer? = nil
  
    private var streamPlayerUrl:NSURL?
    
    private var streamingPlayer:StreamingPlayer!
    
    private var ownPlayerUrl:NSURL?
    
    private var musicName:String?
    
    private var exporter:AudioExporter!
    
     var isParent:Bool!
    
     var networkCom:NetworkCommunicater!
    
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
        
        let nc:NotificationCenter = NotificationCenter.default
        let accesoryEvent:MPRemoteCommandCenter = MPRemoteCommandCenter.shared()
        accesoryEvent.togglePlayPauseCommand.addTarget(self, action: #selector(SecondViewController.accesoryToggled(event:)))
        UIApplication.shared.beginReceivingRemoteControlEvents()
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
        networkCom.addObserver(self as NSObject, forKeyPath: "peerNameArray", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "artImage", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "recvStr", options: [.new,.old], context: nil)
        networkCom.addObserver(self as NSObject, forKeyPath: "audioData", options: [.new,.old], context: nil)
        
        streamingPlayer = StreamingPlayer()
        selectBtn.isHidden = !isParent!
}
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func accesoryToggled(event:MPRemoteCommandEvent){
        print("させない")
    }
    private func removeOb(){
        networkCom.removeObserver(self as NSObject, forKeyPath: "peerNameArray")
        networkCom.removeObserver(self as NSObject, forKeyPath: "artImage")
        networkCom.removeObserver(self as NSObject, forKeyPath: "recvStr")
        networkCom.removeObserver(self as NSObject, forKeyPath: "audioData")
        
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let key = keyPath{
            if key == "peerNameArray"{
                if networkCom.peerNameArray.count == 0{
                    DispatchQueue.main.async {
                        self.segueSecondtofirst()//接続人数が0になったらもとの画面に戻る
                        self.networkCom.stopsendingAudio()
                    }
                }
        }else if key == "artImage"{
                DispatchQueue.main.async {
                    self.titleArt.image = self.networkCom.artImage
                }
                
        }else if key == "recvStr"{
            if networkCom.recvStr == "play"{
                playAudio()
            }else if networkCom.recvStr == "pause"{
                    pauseAudio()
            }else if networkCom.recvStr == "stop"{
                stopAudioStream()
                resetStream()
            }else{
                DispatchQueue.main.async {
                    
                    self.titlelabel.text = self.networkCom.recvStr
                    self.view.setNeedsDisplay()
                    self.stopAudioStream()
                    self.resetStream()
                    self.changeVolume(value: self.volumeSlider.value * self.volumeSlider.value)
                }
                
                            }
        }else if key == "audioData"{
                
                streamingPlayer.recvAudio(networkCom.audioData as Data!)
        }else if key == "convertComp"{
                if change?[.newKey] as! Bool == true{
                   
                    DispatchQueue.main.async(execute: {() -> Void in
                        if self.streamPlayerUrl != nil{
                            if let data = NSData(contentsOf: self.streamPlayerUrl! as URL) {
                                
                                self.networkCom.sendAudiodata(data: data)
                            }
                        }
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
                        self.exporter.removeObserver(self as NSObject, forKeyPath: "convertComp")
                        SVProgressHUD.dismiss(withDelay: Double(self.networkCom.peerNameArray.count) * 2.0)
                    })
                    
                }
            }
        
     }
}
    @IBAction func restart(_ sender: AnyObject) {
       
        if isParent!{
           networkCom.sendStr(str: "play")
        }
        playAudio()
}
    @IBAction func stopBtnTapped(_ sender: AnyObject){
        if isParent!{
            networkCom.sendStr(str: "pause")
        }
        pauseAudio()
    }
    @IBAction func selectBtnTapped(_ sender: AnyObject) {
       
        let picker = MPMediaPickerController()
        picker.delegate = self
        picker.allowsPickingMultipleItems = false
        present(picker,animated: true,completion: nil)
        
    }
   
    @IBAction func returnBtn(_ sender: AnyObject) {
        if isParent!{
            networkCom.stopsendingAudio()
            deleteFile()
        }
        stopAudioStream()
        removeOb()
        

    }
    
   
    
    @IBAction func volumeSliderChanged(_ sender: UISlider) {
        changeVolume(value: sender.value * sender.value)
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
        if isParent && player != nil{
            player?.play()
        }else if streamingPlayer != nil{
            streamingPlayer.play()
        }
        
    }
    func pauseAudio(){
        if isParent && player != nil{
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
        if player != nil && isParent{
            player?.volume = value
        }else if streamingPlayer != nil{
            streamingPlayer.changeVolume(value)
        }
    }
    //MARK: -Segue
    func segueSecondtofirst(){
        stopAudioStream()
        removeOb()
        deleteFile()
        performSegue(withIdentifier: "2to1", sender: nil)
        
    }
       //MARK: - MPMediapicker
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        networkCom.stopsendingAudio()
        self.deleteFile()
        self.toPlayItem = mediaItemCollection.items[0]
        self.musicName =  self.toPlayItem.value(forProperty: MPMediaItemPropertyTitle) as? String
        self.titlelabel.text = self.musicName
        if toPlayItem.value(forProperty: MPMediaItemPropertyArtwork) != nil{
            let artwork:MPMediaItemArtwork  = (self.toPlayItem.value(forProperty: MPMediaItemPropertyArtwork) as? MPMediaItemArtwork)!
            
            networkCom.artImage = artwork.image(at: artwork.bounds.size)
            self.titleArt.image = networkCom.artImage

        }else{
            networkCom.artImage = nil
            DispatchQueue.main.async {
                 self.titleArt.image = UIImage(named: "no_image.png")
            }
           
            
            print("Noimaage")
        }
        if networkCom.artImage != nil{
                networkCom.sendImage(image: networkCom.artImage)
        }else{
            networkCom.sendStr(str: "noimage")
            
        }
        
            self.networkCom.sendStr(str: self.musicName!)
        

       
                        mediaPicker.dismiss(animated: true, completion: nil)
         DispatchQueue.main.async(execute: {() -> Void in
                       SVProgressHUD.show(withStatus: "準備中")})
            self.streamPlayerUrl = self.prepareAudioStreaming(item: self.toPlayItem)
        
    }
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
    func prepareAudioStreaming(item :MPMediaItem) -> NSURL {
        
        exporter = AudioExporter()
        exporter.addObserver(self as NSObject, forKeyPath: "convertComp", options: [.old,.new], context: nil)//変換が終わったかどうかを判断するキー
        let url = exporter.convertItemtoAAC(item: item)
        self.ownPlayerUrl = url[1]
              return url[0] as NSURL
    }
    

}

