//
//  KABLocalAudioPlayer.swift
//  SharePlay2
//
//  Created by 椛島優 on 2017/04/01.
//  Copyright © 2017年 椛島優. All rights reserved.
//

import UIKit

class KABLocalAudioPlayer: AVAudioPlayer {
    var playlist:[URL?]!
    var playingIndex:Int!
    var numOfPlaylist:Int!
    override init() {
        super.init()
        playlist = []
        playingIndex = 0
        numOfPlaylist = playlist.count
    }
}
