//
//  SocketEngineSpec.swift
//  snapper-swift
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

@objc public protocol SocketEngineSpec {
    weak var client: SocketEngineClient? {get set}
    var cookies: [NSHTTPCookie]? {get}
    var sid: String {get}
    var socketPath: String {get}
    var urlPolling: String {get}
    var urlWebSocket: String {get}
    
    init(client: SocketEngineClient, url: String, options: NSDictionary?)
    
    func close()
    func open(opts: [String: AnyObject]?)
    func send(msg: String, withData datas: [NSData])
    func write(msg: String, withType type: SocketEnginePacketType, withData data: [NSData])
}
