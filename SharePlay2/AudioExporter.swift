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
    
    func convertItemtoAAC(item:MPMediaItem) -> [NSURL] {
        
        let url:NSURL = item.value(forProperty: MPMediaItemPropertyAssetURL) as! NSURL
        let urlAsset:AVURLAsset = AVURLAsset(url: url as URL)
        let exportSession:AVAssetExportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPresetAppleM4A)!
        exportSession.outputFileType = exportSession.supportedFileTypes[0]
        
        //Documentsフォルダに保存していく
        let docDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)[0]
        
        let itemTitleString:String = item.value(forProperty: MPMediaItemPropertyTitle) as! String
        
        let filePath:String = docDir + "/" + itemTitleString + ".m4a"
        
        let savePathforCAF:String = docDir + "/" + itemTitleString + ".caf"
        exportSession.outputURL = NSURL(fileURLWithPath: filePath) as URL
        let fileManager:FileManager = FileManager()
        let saveUrlforCAF:NSURL = NSURL(fileURLWithPath: savePathforCAF)
        //ファイルの消去作業　べつの場所でやろう
        //        fileManager.removeItemAtPath(filePath)
        //        fileManager.removeItemAtPath(savePath)
        do{
            try fileManager.createDirectory(atPath: docDir, withIntermediateDirectories: true, attributes: nil)
            
        }catch{
            print("Cannnot make a direc†ory")
        }
        let savePathforAAC:String = docDir + "/" + itemTitleString + ".aac"
        let saveUrlforAAC = NSURL(fileURLWithPath: savePathforAAC)
        
        //ここまで準備
        exportSession.exportAsynchronously(completionHandler: { () -> Void in
            print("Export Complete")
            
            let converter:AudioConverter = AudioConverter()
            
            let extConverter:ExtAudioConverter = ExtAudioConverter()
            
            
            converter.convert(from: exportSession.outputURL, to: saveUrlforCAF as URL!)
            
            extConverter.convert(from: saveUrlforCAF as URL!, to: saveUrlforAAC as URL!)
            
            
            
        })
        return [saveUrlforAAC,exportSession.outputURL! as NSURL]
        
        
        
    }
}
