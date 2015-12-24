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

    let snapper = SnapperClient(socketURL: "snapper.project.bi/websocket", options: [.Log(false), .ConnectParams(["token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI1NWM4MTdmOGU3MTVmYTk5MmExOTNlOTkiLCJleHAiOjE0NTA5MzYwODd9.Y9gk3d3YTE3loyUxWSxiVJzHjhe12bn5O5qGsuJ89JE"])], subscribeURL:"https://www.teambition.com",subscribeToken:"ff")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        snapper.connect()
        
        snapper.on("connect") { (data) -> Void in
            print("connect")
            print(self.snapper.status)
        }
        
        snapper.on("error") { (data) -> Void in
            
        }
        
        snapper.on("reconnect") { (data) -> Void in
            
        }
        
        snapper.message { (message: SnapperMessage) -> Void in
            print(message.items)
            self.snapper.replay(message.id)
        }
        snapper.join("56333d241aa92ac80a957844")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

