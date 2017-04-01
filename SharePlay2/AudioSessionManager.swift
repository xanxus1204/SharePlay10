//
//  AudioSessionManager.swift
//  SharePlay2
//
//  Created by 椛島優 on 2017/04/01.
//  Copyright © 2017年 椛島優. All rights reserved.
//

import UIKit

class AudioSessionManager: NSObject {
    let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
    func setSessionPlayandRecord(){
        
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback, with: AVAudioSessionCategoryOptions.mixWithOthers)//バックグラウンド再生を許可 他の曲とミックス
        } catch  {
            print("Can't set category")
        }
        // sessionのアクティブ化
        do {
            try audioSession.setActive(true)
        } catch {
            print("Can't active")

        }
    }
   
    func addAudioSessionObservers() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(AudioSessionManager.handleInterruption(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
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
