//
//  SnapperMessage.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//
import Foundation

public class SnapperMessage: NSObject {
    public let id: AnyObject!
    public let message: String!
    public let items: NSArray?
    override public var description: String {
        return "SocketAnyEvent: Event: \(message) items: \(items ?? nil)"
    }
    
    init(id: AnyObject, message: String, items: NSArray?) {
        self.id = id
        self.message = message
        self.items = items
    }
}
