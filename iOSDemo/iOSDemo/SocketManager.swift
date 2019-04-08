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
        
        let snapper = SnapperClient(socketURL: "messaging.project.ci/websocket", options: [.secure(false), .log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcHBJRCI6IjViM2MzODE5ODBkNDM1MDA2YzIzMWU4OCIsImV4cCI6MTU1NTE0MjA4Nywic291cmNlIjoiIiwidXNlcklkIjoiNTVjMDVmOTY3MDRmYjhmMjVkY2Y2YzI1In0.kbSYmbNz1fBkVEVzx7QdHp3_IL21U9we5MUl1j6J-2k"])])
//        let snapper = SnapperClient(socketURL: "messaging.teambition.net/websocket", options: [.log(true), .connectParams(["token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcHBJRCI6IjU5MzdiMTBiODM5NjMyMDA0NDRiMWZmOCIsImV4cCI6MTUwMTU3MzIyMSwic291cmNlIjoiaW9zIiwidXNlcklkIjoiNTJhNmNjMmRlZjY2YmM5ODBjMDAwMzEyIn0.0BIV0dIVUph3Sa0WW3YavtiLN6Pp7UvL4-W9gLUO_Uo"]), .secure(true)])
        
        snapper.on("connect") { (data) -> Void in
            print("connenct \(String(describing: self.snapper?.status))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
                self.snapper?.refreshToken(completion: { (newToken) in
                    print("new TCM Token: \(newToken)")
                })
            })
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
            self.snapper?.reply(message.id ?? "")
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
