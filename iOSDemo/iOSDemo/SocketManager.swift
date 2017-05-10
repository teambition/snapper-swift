//
//  SocketManager.swift
//  Teambition
//
//  Created by ChenHao on 12/24/15.
//  Copyright © 2015 Teambition. All rights reserved.
//

import UIKit
import Snapper

final class SocketManager {
    
    typealias MessageCallback = (_ event: String, _ messageObject: Any?) -> Void
    typealias StatusObserver = (_ status: SnapperClietnStatus) -> Void
    
    var snapper: SnapperClient?
    var statusObserver: StatusObserver?
    static let shared = SocketManager()
    fileprivate var subscribes = [String: [String: MessageCallback]]()
    
    
    private init() {}
    
    // MARK: - Connect & Disconnect
    
    func connectToServer() {
        connect(withToken: "token")
    }
    
    func connect(withToken snapperToken: String = "") {
        if let oldSnapper = self.snapper {
            print("release old snapper: \(oldSnapper)")
            self.snapper = nil
        }
        
//        let snapper = SnapperClient(socketURL: "snapper.project.bi/websocket", options: [.secure(false), .log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0OTQ0OTkwMDAsInVzZXJJZCI6IjU1YzA1Zjk2NzA0ZmI4ZjI1ZGNmNmMyNSIsInNvdXJjZSI6ImlvcyJ9.pLi4GjFGh3DAbSYcuoqr7eEFKrZiTf-eTgKb2ewtJIw"])])
        let snapper = SnapperClient(socketURL: "push.teambition.com/websocket", options: [.log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0OTQ0NzY0NTgsInVzZXJJZCI6IjU0MjU0MmZmODgyYTZjNzAwYmI5MzA2YiIsInNvdXJjZSI6ImlvcyJ9.Wo1S93roKzdFuIeEpZDLqrKuwhJ1nnZ0Cf_VZ48ENi0"]), .secure(true)])
        snapper.on("connect") { (data) -> Void in
            print("connenct \(String(describing: self.snapper?.status))")
        }
        
        snapper.on("error") { (data) -> Void in
            print("error \(data)")
        }
        
        snapper.on("reconnect") { (data) -> Void in
            print("reconnect \(data)")
        }
        
        snapper.on("disconnect") { (data) in
            print("disconnect reason: \(data)")
        }
        
        snapper.message { (message: SnapperMessage) -> Void in
            print("\(String(describing: message.items?.count))")
            
            self.snapper?.replay(message.id)
        }
        
        snapper.connect()
        self.snapper = snapper
    }
    
    func disconnect() {
        snapper?.disconnect()
    }
    
    func close() {
        if let snapper = snapper {
            snapper.close()
        }
    }
    
    func tryReconnectIfNeeded() {
        if let status = snapper?.status, (status != .connected && status != .reconnecting && status != .connecting) {
            disconnect()
            connectToServer()
        }
    }
}
