//
//  SocketEnginePacketType.swift
//  snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

@objc public enum SocketEnginePacketType: Int {
    case open, close, ping, pong, message, upgrade, noop
}
