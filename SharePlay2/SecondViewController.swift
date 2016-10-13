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
    
    private var recvData:Data!
    
   private var toPlayItem:MPMediaItem!
    
   private var player:AVAudioPlayer!
  
    private var playerUrl:NSURL?
    
    private var streamingPlayer:StreamingPlayer!
    
   
    @IBOutlet weak var titlelabel: UILabel!

    @IBOutlet weak var titleArt: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        session.delegate = self
        recvData = Data()
        let audiosession = AVAudioSession.sharedInstance()
        streamingPlayer = StreamingPlayer()
        streamingPlayer.start()
        do {
            try audiosession.setCategory(AVAudioSessionCategoryPlayback)
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
                        sendData(data: data)
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
        streamingPlayer.recvAudio(data)
//        if (NSString(data: data, encoding: String.Encoding.utf8.rawValue) == "end"){
//            print("受信完了")
////             let docDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)[0]
////            let path = docDir + "/test.m4a"
////            print(path)
////            let manager = FileManager.default
////            
////            manager.createFile(atPath: path, contents: recvData, attributes: nil)
////            recvData = Data()
//         
//        }else{
//            
//               // recvData.append(data)
//
//            
//            
//        }
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
    func sendData(data:NSData) -> () {
        var splitDataSize = bufferSize
        //var indexofData = 0
        var buf = Array<Int8>(repeating: 0, count: bufferSize)
        //var error: NSError!
        var tempData = NSMutableData()
        var index = 0
        while index < data.length {
            
            if (index >= data.length-bufferSize) || (data.length < bufferSize) {
                splitDataSize = data.length - index
                buf = Array<Int8>(repeating: 0, count: splitDataSize)
                
                data.getBytes(&buf, range: NSMakeRange(index,splitDataSize))
                tempData = NSMutableData(bytes: buf, length: splitDataSize)
                do {
                    try session.send(tempData as Data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                    let finish = "end"
                    let finData = finish.data(using: String.Encoding.utf8)
                    try session.send(finData! as Data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                    
                }catch{
                    
                    print("Send Failed")
                }
                
            }else{
                data.getBytes(&buf, range: NSMakeRange(index,splitDataSize))
                tempData = NSMutableData(bytes: buf,length:splitDataSize)
                do{
                    try session.send(tempData as Data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
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
        self.titlelabel.text =  self.toPlayItem.value(forProperty: MPMediaItemPropertyTitle) as? String
        let artwork:MPMediaItemArtwork  = (self.toPlayItem.value(forProperty: MPMediaItemPropertyArtwork) as? MPMediaItemArtwork)!
        self.titleArt.image = artwork.image(at: artwork.bounds.size)
        self.playerUrl = prepareAudioStreaming(item: self.toPlayItem)
        mediaPicker .dismiss(animated: true, completion: nil)
        
    }
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
    func prepareAudioStreaming(item :MPMediaItem) -> NSURL {
       let exporter:AudioExporter = AudioExporter()
    let url = exporter.convertItemtoAAC(item: item)
              return url as NSURL
    }
    
  

}


