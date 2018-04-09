//
//  SnapperClientOption.swift
//  snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

protocol ClientOption: CustomStringConvertible, Hashable {
    func getSocketIOOptionValue() -> Any?
}

public enum SnapperClientOption: ClientOption {
    case connectParams([String: Any])
    case cookies([HTTPCookie])
    case extraHeaders([String: String])
    case forceNew(Bool)
    case forcePolling(Bool)
    case forceWebsockets(Bool)
    case handleQueue(DispatchQueue)
    case log(Bool)
    case logger(SocketLogger)
    case nsp(String)
    case path(String)
    case reconnects(Bool)
    case reconnectAttempts(Int)
    case reconnectWait(Int)
    case secure(Bool)
    case selfSigned(Bool)
    case sessionDelegate(URLSessionDelegate)
    case voipEnabled(Bool)

    public var description: String {
        if let label = Mirror(reflecting: self).children.first?.label {
            return String(label[label.startIndex]).lowercased() + String(label.dropFirst())
        } else {
            return ""
        }
    }

    public var hashValue: Int {
        return description.hashValue
    }

    static func keyValueToSocketIOClientOption(_ key: String, value: Any) -> SnapperClientOption? {
        switch (key, value) {
        case ("connectParams", let params as [String: Any]):
            return .connectParams(params)
        case ("reconnects", let reconnects as Bool):
            return .reconnects(reconnects)
        case ("reconnectAttempts", let attempts as Int):
            return .reconnectAttempts(attempts)
        case ("reconnectWait", let wait as Int):
            return .reconnectWait(wait)
        case ("forceNew", let force as Bool):
            return .forceNew(force)
        case ("forcePolling", let force as Bool):
            return .forcePolling(force)
        case ("forceWebsockets", let force as Bool):
            return .forceWebsockets(force)
        case ("nsp", let nsp as String):
            return .nsp(nsp)
        case ("cookies", let cookies as [HTTPCookie]):
            return .cookies(cookies)
        case ("log", let log as Bool):
            return .log(log)
        case ("logger", let logger as SocketLogger):
            return .logger(logger)
        case ("sessionDelegate", let delegate as URLSessionDelegate):
            return .sessionDelegate(delegate)
        case ("path", let path as String):
            return .path(path)
        case ("extraHeaders", let headers as [String: String]):
            return .extraHeaders(headers)
        case ("handleQueue", let queue as DispatchQueue):
            return .handleQueue(queue)
        case ("voipEnabled", let enable as Bool):
            return .voipEnabled(enable)
        case ("secure", let secure as Bool):
            return .secure(secure)
        case ("selfSigned", let selfSigned as Bool):
            return .selfSigned(selfSigned)
        default:
            return nil
        }
    }

    func getSocketIOOptionValue() -> Any? {
        return Mirror(reflecting: self).children.first?.value
    }
}

public func ==(lhs: SnapperClientOption, rhs: SnapperClientOption) -> Bool {
    return lhs.description == rhs.description
}

extension Set where Element: ClientOption {
    mutating func insertIgnore(_ element: Element) {
        if !contains(element) {
            insert(element)
        }
    }

    static func NSDictionaryToSocketOptionsSet(_ dict: NSDictionary) -> Set<SnapperClientOption> {
        var options = Set<SnapperClientOption>()

        for (rawKey, value) in dict {
            if let key = rawKey as? String, let opt = SnapperClientOption.keyValueToSocketIOClientOption(key, value: value) {
                options.insertIgnore(opt)
            }
        }

        return options
    }

    func SocketOptionsSetToNSDictionary() -> NSDictionary {
        let options = NSMutableDictionary()

        for option in self {
            options[option.description] = option.getSocketIOOptionValue()
        }

        return options
    }
}
