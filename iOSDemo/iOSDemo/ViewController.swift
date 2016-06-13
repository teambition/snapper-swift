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
    let snapper = SnapperClient(socketURL: "push.teambition.com/websocket", options: [.Log(true), .ConnectParams(["token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI1NWE4NzZlMWEyZWUxOGQ1NjM5MzI4YmEiLCJleHAiOjE0NjU5NzQ2NDF9._fANnb-MSq9Aw3riUFhCyrVmG-Iu1Z-MZSl87_TiGiw"]), .Secure(true)])
    
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

