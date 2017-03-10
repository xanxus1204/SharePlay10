//
//  SongItemCell.swift
//  SharePlay2
//
//  Created by 椛島優 on 2017/01/21.
//  Copyright © 2017年 椛島優. All rights reserved.
//

import UIKit

class SongItemCell: UITableViewCell {

    @IBOutlet weak var albumartworkView: UIImageView!
    @IBOutlet weak var songTitleLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    func update(withItem item: SongItem) {
        self.backgroundColor = UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0)
        songTitleLabel.text = item.songTitle
        if item.image != nil{
            albumartworkView.image = item.image
        }else{
            albumartworkView.image = UIImage(named: "no_image.png")
        }
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
