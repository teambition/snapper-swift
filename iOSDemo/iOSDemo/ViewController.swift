//
//  ViewController.swift
//  iOSDemo
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import UIKit
import Snapper

class ViewController: UIViewController {

    let snapper = SnapperClient(socketURL: "snapper.project.bi/websocket", options: [.Secure(false), .Log(true), .ConnectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0NjY5MDU3MzUsInVzZXJJZCI6IjU2OTg2ZDQzNTQyY2UxYTI3OThjOGNmYiIsInNvdXJjZSI6InRlYW1iaXRpb24ifQ.QycjEWs95wjdn-xrnDciEFyU6F5sMHhFhSMtASVj-_c"])])
//    let snapper = SnapperClient(socketURL: "push.teambition.com/websocket", options: [.Log(true), .ConnectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0NjY5MDUyOTEsInVzZXJJZCI6IjU1YTg3NmUxYTJlZTE4ZDU2MzkzMjhiYSIsInNvdXJjZSI6InRlYW1iaXRpb24ifQ.QBtOLg1O-fFRq2V5L--xTm5OY9ZOsl_DmpUiGBauGaA"]), .Secure(true)])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        snapper.connect()
        
        snapper.on("connect") { (data) -> Void in
            print(self.snapper.status)
        }
        
        snapper.on("error") { (data) -> Void in
            
        }
        
        snapper.on("reconnect") { (data) -> Void in
            
        }
        
        snapper.message { (message: SnapperMessage) -> Void in
            print(message.items?.count)
            
            self.snapper.replay(message.id)
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

