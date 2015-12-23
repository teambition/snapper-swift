//
//  SocketLogger.swift
//  snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

public protocol SocketLogger: class {
    /// Whether to log or not
    var log: Bool {get set}
    
    /// Normal log messages
    func log(message: String, type: String, args: AnyObject...)
    
    /// Error Messages
    func error(message: String, type: String, args: AnyObject...)
}

public extension SocketLogger {
    func log(message: String, type: String, args: AnyObject...) {
        abstractLog("Log", message: message, type: type, args: args)
    }
    
    func error(message: String, type: String, args: AnyObject...) {
        abstractLog("ERROR", message: message, type: type, args: args)
    }
    
    private func abstractLog(logType: String, message: String, type: String, args: [AnyObject]) {
        guard log else { return }
        
        let newArgs = args.map {arg -> CVarArgType in String(arg)}
        let replaced = String(format: message, arguments: newArgs)
        
        NSLog("%@ %@: %@", logType, type, replaced)
    }
}

class DefaultSocketLogger: SocketLogger {
    static var Logger: SocketLogger = DefaultSocketLogger()
    
    var log = false
}
