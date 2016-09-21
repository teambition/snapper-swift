//
//  SnapperMessage.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//
import Foundation

open class SnapperMessage: NSObject {
    open let id: Any!
    open let message: String!
    open let items: NSArray?
    override open var description: String {
        return "SocketAnyEvent: Event: \(message) items: \(items ?? nil)"
    }

    init(id: Any, message: String, items: NSArray?) {
        self.id = id
        self.message = message
        self.items = items
    }
}
