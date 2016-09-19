//
//  SnapperClietnStatus.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

@objc public enum SnapperClietnStatus: Int, CustomStringConvertible {
    case notConnected, closed, connecting, connected, reconnecting

    public var description: String {
        switch self {
        case .notConnected:
            return "Not Connected"
        case .closed:
            return "Closed"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting"
        }
    }
}
