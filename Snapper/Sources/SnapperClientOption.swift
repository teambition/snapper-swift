//
//  SnapperClientOption.swift
//  snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

protocol ClientOption: CustomStringConvertible, Hashable {
    func getSocketIOOptionValue() -> AnyObject?
}

public enum SnapperClientOption: ClientOption {
    case ConnectParams([String: AnyObject])
    case Cookies([NSHTTPCookie])
    case ExtraHeaders([String: String])
    case ForceNew(Bool)
    case ForcePolling(Bool)
    case ForceWebsockets(Bool)
    case HandleQueue(dispatch_queue_t)
    case Log(Bool)
    case Logger(SocketLogger)
    case Nsp(String)
    case Path(String)
    case Reconnects(Bool)
    case ReconnectAttempts(Int)
    case ReconnectWait(Int)
    case Secure(Bool)
    case SelfSigned(Bool)
    case SessionDelegate(NSURLSessionDelegate)
    case VoipEnabled(Bool)
    
    public var description: String {
        if let label = Mirror(reflecting: self).children.first?.label {
            return String(label[label.startIndex]).lowercaseString + String(label.characters.dropFirst())
        } else {
            return ""
        }
    }
    
    public var hashValue: Int {
        return description.hashValue
    }
    
    static func keyValueToSocketIOClientOption(key: String, value: AnyObject) -> SnapperClientOption? {
        switch (key, value) {
        case ("connectParams", let params as [String: AnyObject]):
            return .ConnectParams(params)
        case ("reconnects", let reconnects as Bool):
            return .Reconnects(reconnects)
        case ("reconnectAttempts", let attempts as Int):
            return .ReconnectAttempts(attempts)
        case ("reconnectWait", let wait as Int):
            return .ReconnectWait(wait)
        case ("forceNew", let force as Bool):
            return .ForceNew(force)
        case ("forcePolling", let force as Bool):
            return .ForcePolling(force)
        case ("forceWebsockets", let force as Bool):
            return .ForceWebsockets(force)
        case ("nsp", let nsp as String):
            return .Nsp(nsp)
        case ("cookies", let cookies as [NSHTTPCookie]):
            return .Cookies(cookies)
        case ("log", let log as Bool):
            return .Log(log)
        case ("logger", let logger as SocketLogger):
            return .Logger(logger)
        case ("sessionDelegate", let delegate as NSURLSessionDelegate):
            return .SessionDelegate(delegate)
        case ("path", let path as String):
            return .Path(path)
        case ("extraHeaders", let headers as [String: String]):
            return .ExtraHeaders(headers)
        case ("handleQueue", let queue as dispatch_queue_t):
            return .HandleQueue(queue)
        case ("voipEnabled", let enable as Bool):
            return .VoipEnabled(enable)
        case ("secure", let secure as Bool):
            return .Secure(secure)
        case ("selfSigned", let selfSigned as Bool):
            return .SelfSigned(selfSigned)
        default:
            return nil
        }
    }
    
    func getSocketIOOptionValue() -> AnyObject? {
        return Mirror(reflecting: self).children.first?.value as? AnyObject
    }
}

public func ==(lhs: SnapperClientOption, rhs: SnapperClientOption) -> Bool {
    return lhs.description == rhs.description
}

extension Set where Element: ClientOption {
    mutating func insertIgnore(element: Element) {
        if !contains(element) {
            insert(element)
        }
    }
    
    static func NSDictionaryToSocketOptionsSet(dict: NSDictionary) -> Set<SnapperClientOption> {
        var options = Set<SnapperClientOption>()
        
        for (rawKey, value) in dict {
            if let key = rawKey as? String, opt = SnapperClientOption.keyValueToSocketIOClientOption(key, value: value) {
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
