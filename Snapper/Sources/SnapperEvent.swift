//
//  SnapperEvent.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

@objc public final class SnapperEvent: NSObject {
    public let event: String!
    public let items: NSArray?
    override public var description: String {
        return "SocketAnyEvent: Event: \(event) items: \(items ?? nil)"
    }
    
    init(event: String, items: NSArray?) {
        self.event = event
        self.items = items
    }
}