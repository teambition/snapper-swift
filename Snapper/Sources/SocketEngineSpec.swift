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
    var cookies: [HTTPCookie]? {get}
    var sid: String {get}
    var socketPath: String {get}
    var urlPolling: String {get}
    var urlWebSocket: String {get}

    init(client: SocketEngineClient, url: String, options: NSDictionary?)

    func close()
    func open(_ opts: [String: Any]?)
    func send(_ msg: String, withData datas: [Data])
    func write(_ msg: String, withType type: SocketEnginePacketType, withData data: [Data])
}
