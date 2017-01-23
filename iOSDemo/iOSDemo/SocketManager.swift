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
        
        //let snapper = SnapperClient(socketURL: "snapper.project.bi/websocket", options: [.secure(false), .log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0Nzg2Nzc5NzIsInVzZXJJZCI6IjU3Yzk1Yjk0NWE5OTkwZmI0ODAwN2YxZSIsInNvdXJjZSI6InRlYW1iaXRpb24ifQ.GEkp9KlCQqGKL1Ku0-vZdLTynM_SGqQK25KYC72B9J0"])])
        let snapper = SnapperClient(socketURL: "push.teambition.com/websocket", options: [.log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE0ODUzMTI4NjksInVzZXJJZCI6IjUyYTZjYzJkZWY2NmJjOTgwYzAwMDMxMiIsInNvdXJjZSI6InRlYW1iaXRpb24ifQ.9oUN0oA6y7Q43XvopR9GTnKVTShlA5UAEHetABeQy30"]), .secure(true)])
        snapper.on("connect") { (data) -> Void in
            print("connenct \(self.snapper?.status)")
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
            print("\(message.items?.count)")
            
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
