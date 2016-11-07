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
        let cacheDir = NSTemporaryDirectory()
        
        let itemTitleString:String = item.value(forProperty: MPMediaItemPropertyTitle) as! String
        
        let filePath:String = cacheDir + "/" + itemTitleString + ".m4a"
        
        
        exportSession.outputURL = NSURL(fileURLWithPath: filePath) as URL
        let fileManager:FileManager = FileManager()
        
        do{
            try fileManager.createDirectory(atPath: cacheDir, withIntermediateDirectories: true, attributes: nil)
            
        }catch{
            print("Cannnot make a direc†ory")
        }
        let savePathforAAC:String = cacheDir + "/" + itemTitleString + ".aac"
        let saveUrlforAAC = NSURL(fileURLWithPath: savePathforAAC)
        
        //ここまで準備
        exportSession.exportAsynchronously(completionHandler: { () -> Void in
            print("Export Complete")
            
            
            
            let extConverter:ExtAudioConverter = ExtAudioConverter()
            
            
            extConverter.convert(from:exportSession.outputURL, to: saveUrlforAAC as URL!)
           
            
        })
        return [saveUrlforAAC,exportSession.outputURL! as NSURL]
        
        
        
    }
}
