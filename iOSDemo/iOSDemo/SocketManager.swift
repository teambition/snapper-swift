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
        
      // let snapper = SnapperClient(socketURL: "messaging.project.ci/websocket", options: [.secure(false), .log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcHBJRCI6IjU4Zjk1ZTkyYzA2YTU0NmY3ZGFiNzNjNyIsImV4cCI6MTUwMTU3MTA2NCwic291cmNlIjoiaW9zIiwidXNlcklkIjoiNTdjOTViOTQ1YTk5OTBmYjQ4MDA3ZjFlIn0.qQuVVQYanYYIPJvZQOC9-ls-w6zYLdd_-bMAoinW2bQ"])])
        let snapper = SnapperClient(socketURL: "messaging.teambition.net/websocket", options: [.log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcHBJRCI6IjU5MzdiMTBiODM5NjMyMDA0NDRiMWZmOCIsImV4cCI6MTUwMTU3MzIyMSwic291cmNlIjoiaW9zIiwidXNlcklkIjoiNTJhNmNjMmRlZjY2YmM5ODBjMDAwMzEyIn0.0BIV0dIVUph3Sa0WW3YavtiLN6Pp7UvL4-W9gLUO_Uo"]), .secure(true)])
        
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
            
            self.snapper?.reply(message.id)
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
