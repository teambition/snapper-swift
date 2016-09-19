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
    var isLog: Bool {get set}

    /// Normal log messages
    func log(_ message: String, type: String, args: Any...)

    /// Error Messages
    func error(_ message: String, type: String, args: Any...)
}

public extension SocketLogger {
    func log(_ message: String, type: String, args: Any...) {
        abstractLog("Log", message: message, type: type, args: args)
    }

    func error(_ message: String, type: String, args: Any...) {
        abstractLog("ERROR", message: message, type: type, args: args)
    }

    fileprivate func abstractLog(_ logType: String, message: String, type: String, args: [Any]) {
        guard isLog else { return }

        let newArgs = args.map {arg -> CVarArg in String(describing: arg)}
        let replaced = String(format: message, arguments: newArgs)

        NSLog("%@ %@: %@", logType, type, replaced)
    }
}

class DefaultSocketLogger: SocketLogger {
    static var Logger: SocketLogger = DefaultSocketLogger()

    var isLog = false
}
