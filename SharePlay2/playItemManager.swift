//
//  playItemManager.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/12/05.
//  Copyright © 2016年 椛島優. All rights reserved.
//

import UIKit
import MediaPlayer
struct playItemProperty {//アイテムのプロパティを持つ構造体
    var albumArtWork:UIImage? = nil
    var musicTitle:String!
    //他にもアルバムのタイトルとか今後載せれるように
}
class playItemManager: NSObject {
    var toPlayItem:MPMediaItem!
    var playItemList:[MPMediaItem]!
    var itemProperty:playItemProperty = playItemProperty()
    var musicTitleArray:[String]!
    var playUrl:URL? = nil
    init(withItems Items:MPMediaItemCollection){
        playItemList = Items.items
        toPlayItem = playItemList[0]
        if let artWork = toPlayItem.artwork{
            itemProperty.albumArtWork = artWork.image(at: artWork.bounds.size)
        }
        for item in playItemList{
            musicTitleArray.append(item.title!)
        }
        itemProperty.musicTitle = musicTitleArray[0]
        playUrl = toPlayItem.assetURL
    }
    func addPlayItems(mediaItems:MPMediaItemCollection) -> () {
        playItemList.append(contentsOf: mediaItems.items)
        for item in playItemList{
            musicTitleArray.append(item.title!)
        }
    }
    func movePlayItem(toIndex index:Int) -> () {
        if index < playItemList.count{
            toPlayItem = playItemList[index]
            if let artWork = toPlayItem.artwork{
                itemProperty.albumArtWork = artWork.image(at: artWork.bounds.size)
            }
            musicTitleArray.remove(at: 0)
            itemProperty.musicTitle = musicTitleArray[0]
            playUrl = toPlayItem.assetURL

        }
        
    }
}
