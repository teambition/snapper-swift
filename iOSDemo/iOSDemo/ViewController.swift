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

//    let snapper = SnapperClient(socketURL: "snapper.project.bi/websocket", options: [.Log(true), .ConnectParams(["token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI1NWM4MTdmOGU3MTVmYTk5MmExOTNlOTkiLCJleHAiOjE0NTExMjA4OTd9.K3FBtEmd4zmdZEAAmDzw_8okgYB8hKtqbZxnuJ2LWFM"])])
    let snapper = SnapperClient(socketURL: "push.teambition.com/websocket", options: [.Log(true), .ConnectParams(["token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI1NTgyM2MwNWZiMDkzMWRiNWM1MzE0NDciLCJleHAiOjE0NTExMjI3MDh9.uHuLTbETtRF0SropvWP9EVdh2F6oOKP5F8619Fe0318"]), .Secure(true)])
    
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

