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

    //let snapper = SnapperClient(socketURL: "snapper.project.bi/websocket", options: [.secure(false), .log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0NjY5MDU3MzUsInVzZXJJZCI6IjU2OTg2ZDQzNTQyY2UxYTI3OThjOGNmYiIsInNvdXJjZSI6InRlYW1iaXRpb24ifQ.QycjEWs95wjdn-xrnDciEFyU6F5sMHhFhSMtASVj-_c"])])
    let snapper = SnapperClient(socketURL: "push.teambition.com/websocket", options: [.log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0NzQ2MDE5NjUsInVzZXJJZCI6IjUzZGI0ZDA3ZjhiNzIyYjM3NTU1MWQ2ZSIsInNvdXJjZSI6InRlYW1iaXRpb24ifQ.UiH7TWdsd6qSzUiYHyMpH9C077tvDjE0i3LAoIu6Rrc"]), .secure(true)])
    
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
