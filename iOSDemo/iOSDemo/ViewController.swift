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

    //let snapper = SnapperClient(socketURL: "snapper.project.bi/websocket", options: [.secure(false), .log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0Nzg2Nzc5NzIsInVzZXJJZCI6IjU3Yzk1Yjk0NWE5OTkwZmI0ODAwN2YxZSIsInNvdXJjZSI6InRlYW1iaXRpb24ifQ.GEkp9KlCQqGKL1Ku0-vZdLTynM_SGqQK25KYC72B9J0"])])
    let snapper = SnapperClient(socketURL: "push.teambition.com/websocket", options: [.log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0Nzg3MTA1NzcsInVzZXJJZCI6IjUyYTZjYzJkZWY2NmJjOTgwYzAwMDMxMiIsInNvdXJjZSI6InRlYW1iaXRpb24ifQ.9B95rV62HHqoWMD74_BdKcpf6YL5hM7rodDN-Aq8ISo"]), .secure(true)])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        snapper.connect()

        snapper.on("connect") { (data) -> Void in
            print(self.snapper.status)
        }

        snapper.on("error") { (data) -> Void in
            print("error")
        }

        snapper.on("reconnect") { (data) -> Void in
            print("reconnect")
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
