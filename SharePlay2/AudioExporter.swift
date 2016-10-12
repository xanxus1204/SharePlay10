//
//  AudioConverter.swift
//  SharePlay
//
//  Created by 椛島優 on 2016/04/22.
//  Copyright © 2016年 椛島優. All rights reserved.
//

import Foundation
import MediaPlayer
class AudioExporter: NSObject {
    
    func convertItemtoAAC(item:MPMediaItem) -> NSURL {
        
        let url:NSURL = item.value(forProperty: MPMediaItemPropertyAssetURL) as! NSURL
        let urlAsset:AVURLAsset = AVURLAsset(url: url as URL)
        let exportSession:AVAssetExportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPresetAppleM4A)!
        exportSession.outputFileType = exportSession.supportedFileTypes[0]
        
        //Documentsフォルダに保存していく
        let docDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)[0]
        
        let itemTitleString:String = item.value(forProperty: MPMediaItemPropertyTitle) as! String
        
        let filePath:String = docDir + "/" + itemTitleString + ".m4a"
        
        exportSession.outputURL = NSURL(fileURLWithPath: filePath) as URL
        let fileManager:FileManager = FileManager()
      
        //ファイルの消去作業　べつの場所でやろう
//        fileManager.removeItemAtPath(filePath)
//        fileManager.removeItemAtPath(savePath)
        do{
            try fileManager.createDirectory(atPath: docDir, withIntermediateDirectories: true, attributes: nil)
            
        }catch{
            print("Cannnot make a direc†ory")
        }
        
        //ここまで準備
        exportSession.exportAsynchronously(completionHandler: { () -> Void in
            print("Export Complete")
            
            
         
            print("変換完了")
            

            
            
        })
        return exportSession.outputURL! as URL! as NSURL
        
        
        
    }
}
