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
    func didError(_ reason: Any)
    func engineDidClose(_ reason: String)
    func parseSocketMessage(_ msg: String)
    func parseBinaryData(_ data: Data)
}
