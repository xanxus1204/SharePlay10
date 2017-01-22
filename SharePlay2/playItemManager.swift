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
    var playListUrl:[URL] = []
    override init() {
        super.init()
    }
    init(withItems Items:MPMediaItemCollection){
        for item in Items.items{
            playListUrl.append(item.assetURL!)
        }
    }
    func addDummyUrl(){
        playListUrl.append(URL(fileURLWithPath: "dummy"))
    }
    func addPlayItems(Items:MPMediaItemCollection) -> () {
        for item in Items.items{
            playListUrl.append(item.assetURL!)
        }
    }
   
}
