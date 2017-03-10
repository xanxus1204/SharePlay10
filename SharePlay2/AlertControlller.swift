//
//  AlertControlller.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/12/13.
//  Copyright © 2016年 椛島優. All rights reserved.
//

import UIKit

class AlertControlller: NSObject{
    
   private var okText:String?
   private var cancelText:String?
   private var alertTitle:String?
   private var alertMessage:String?
    var alert:UIAlertController!
   private var okAction:UIAlertAction!
   private var cancelAction:UIAlertAction!
    
    init(titlestr:String?,messagestr:String?,okTextstr:String?,canceltextstr:String?) {
        alertTitle = titlestr
        alertMessage = messagestr
        okText = okTextstr
        cancelText = canceltextstr
        alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
    }
    func addOkAction(okblock: ( (UIAlertAction) -> Void )?){
        okAction = UIAlertAction(title: okText, style: UIAlertActionStyle.default, handler: okblock)
        alert.addAction(okAction)
    }
    func addCancelAction(cancelblock: ( (UIAlertAction) -> Void )?){
        cancelAction = UIAlertAction(title: cancelText, style: UIAlertActionStyle.cancel, handler: cancelblock)
        alert.addAction(cancelAction)
    }
   
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
