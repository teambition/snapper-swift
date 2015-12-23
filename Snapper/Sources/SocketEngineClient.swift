//
//  SocketEngineClient.swift
//  snapper-swift
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

@objc public protocol SocketEngineClient {
    func didConnect()
    func didError(reason: AnyObject)
    func engineDidClose(reason: String)
    func parseSocketMessage(msg: String)
    func parseBinaryData(data: NSData)
}