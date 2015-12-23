//
//  SnapperClietnStatus.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

@objc public enum SnapperClietnStatus: Int, CustomStringConvertible {
    case NotConnected, Closed, Connecting, Connected, Reconnecting
    
    public var description: String {
        switch self {
        case NotConnected:
            return "Not Connected"
        case Closed:
            return "Closed"
        case Connecting:
            return "Connecting"
        case Connected:
            return "Connected"
        case Reconnecting:
            return "Reconnecting"
        }
    }
}