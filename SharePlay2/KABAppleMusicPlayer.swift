//
//  KABAppleMusicPlayer.swift
//  SharePlay2
//
//  Created by 椛島優 on 2017/04/01.
//  Copyright © 2017年 椛島優. All rights reserved.
//

import UIKit
import MediaPlayer
@available(iOS 10.3, *)
class KABAppleMusicPlayer: NSObject {
    var player:MPMusicPlayerController!
   // var playlist:[URL?]!
    var playingIndex:Int!
    var numOfPlaylist:Int!
    override init() {
        player = MPMusicPlayerController.applicationQueuePlayer()
        playingIndex = 0
        numOfPlaylist = 0
    }
    func addQueueWithStoreIDs(storeIDs:[String])  {
        if (numOfPlaylist == 0) {
            player.setQueueWithStoreIDs(storeIDs)
            numOfPlaylist = storeIDs.count
        }else{
           let queue = MPMusicPlayerStoreQueueDescriptor(storeIDs: storeIDs)
            player.append(queue)
            numOfPlaylist = numOfPlaylist + storeIDs.count
        }
        
    }
    func addQueueWithMPItem(Items:MPMediaItem)  {
        
    }
}
