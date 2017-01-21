//
//  playItemManager.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/12/05.
//  Copyright © 2016年 椛島優. All rights reserved.
//

import UIKit
import MediaPlayer

class playItemManager: NSObject {
    var toPlayItem:MPMediaItem!
    var playItemList:[MPMediaItem] = []
    var playUrl:URL? = nil
    override init() {
        super.init()
    }
    init(withItems Items:MPMediaItemCollection){
        playItemList = Items.items
        toPlayItem = playItemList[0]
        playUrl = toPlayItem.assetURL
    }
    func addPlayItems(mediaItems:MPMediaItemCollection) -> () {
        playItemList.append(contentsOf: mediaItems.items)
    }
    func movePlayItem(toIndex index:Int) -> () {
        if index < playItemList.count{
            toPlayItem = playItemList[index]
            playUrl = toPlayItem.assetURL
                   }
        
    }
}
