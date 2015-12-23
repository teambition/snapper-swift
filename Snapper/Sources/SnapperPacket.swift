//
//  SocketPacket.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

struct SnapperPacket {
    private let placeholders: Int
    private var currentPlace = 0
    
    private static let logType = "SnapperPacket"
    
    let nsp: String
    let id: Int
    let type: PacketType
    
    enum PacketType: Int {
        case Connect, Disconnect, Event, Ack, Error, BinaryEvent, BinaryAck, Message
    }
    
    var args: [AnyObject]? {
        var arr = data
        
        if data.count == 0 {
            return nil
        } else {
            if type == .Event || type == .BinaryEvent {
                arr.removeAtIndex(0)
                return arr
            } else {
                return arr
            }
        }
    }
    
    var binary: [NSData]
    var data: [AnyObject]
    var message: SnapperMessage?
    var description: String {
        return "SocketPacket {type: \(String(type.rawValue)); data: " +
        "\(String(data)); id: \(id); placeholders: \(placeholders); nsp: \(nsp)}"
    }
    
    var event: String {
        return data[0] as? String ?? String(data[0])
    }
    
    var packetString: String {
        return createPacketString()
    }
    
    init(type: SnapperPacket.PacketType, data: [AnyObject] = [AnyObject](), id: Int = -1,
        nsp: String, placeholders: Int = 0, binary: [NSData] = [NSData]()) {
            self.data = data
            self.id = id
            self.nsp = nsp
            self.type = type
            self.placeholders = placeholders
            self.binary = binary
    }
    
    mutating func addData(data: NSData) -> Bool {
        if placeholders == currentPlace {
            return true
        }
        
        binary.append(data)
        currentPlace++
        
        if placeholders == currentPlace {
            currentPlace = 0
            return true
        } else {
            return false
        }
    }
    
    private func completeMessage(message: String, ack: Bool) -> String {
        var restOfMessage = ""
        
        if data.count == 0 {
            return message + "]"
        }
        
        for arg in data {
            if arg is NSDictionary || arg is [AnyObject] {
                do {
                    let jsonSend = try NSJSONSerialization.dataWithJSONObject(arg,
                        options: NSJSONWritingOptions(rawValue: 0))
                    let jsonString = NSString(data: jsonSend, encoding: NSUTF8StringEncoding)
                    
                    restOfMessage += jsonString! as String + ","
                } catch {
                    DefaultSocketLogger.Logger.error("Error creating JSON object in SocketPacket.completeMessage",
                        type: SnapperPacket.logType)
                }
            } else if let str = arg as? String {
                restOfMessage += "\"" + ((str["\n"] ~= "\\\\n")["\r"] ~= "\\\\r") + "\","
            } else if arg is NSNull {
                restOfMessage += "null,"
            } else {
                restOfMessage += "\(arg),"
            }
        }
        
        if restOfMessage != "" {
            restOfMessage.removeAtIndex(restOfMessage.endIndex.predecessor())
        }
        
        return message + restOfMessage + "]"
    }
    
    private func createAck() -> String {
        let msg: String
        
        if type == PacketType.Ack {
            if nsp == "/" {
                msg = "3\(id)["
            } else {
                msg = "3\(nsp),\(id)["
            }
        } else {
            if nsp == "/" {
                msg = "6\(binary.count)-\(id)["
            } else {
                msg = "6\(binary.count)-\(nsp),\(id)["
            }
        }
        
        return completeMessage(msg, ack: true)
    }
    
    
    private func createMessageForEvent() -> String {
        let message: String
        
        if type == PacketType.Event {
            if nsp == "/" {
                if id == -1 {
                    message = "2["
                } else {
                    message = "2\(id)["
                }
            } else {
                if id == -1 {
                    message = "2\(nsp),["
                } else {
                    message = "2\(nsp),\(id)["
                }
            }
        } else {
            if nsp == "/" {
                if id == -1 {
                    message = "5\(binary.count)-["
                } else {
                    message = "5\(binary.count)-\(id)["
                }
            } else {
                if id == -1 {
                    message = "5\(binary.count)-\(nsp),["
                } else {
                    message = "5\(binary.count)-\(nsp),\(id)["
                }
            }
        }
        
        return completeMessage(message, ack: false)
    }
    
    private func createPacketString() -> String {
        let str: String
        
        if type == .Event || type == .BinaryEvent {
            str = createMessageForEvent()
        } else {
            str = createAck()
        }
        
        return str
    }
    
    mutating func fillInPlaceholders() {
        for i in 0..<data.count {
            if let str = data[i] as? String, num = str["~~(\\d)"].groups() {
                // Fill in binary placeholder with data
                data[i] = binary[Int(num[1])!]
            } else if data[i] is NSDictionary || data[i] is NSArray {
                data[i] = _fillInPlaceholders(data[i])
            }
        }
    }
    
    private mutating func _fillInPlaceholders(data: AnyObject) -> AnyObject {
        if let str = data as? String {
            if let num = str["~~(\\d)"].groups() {
                return binary[Int(num[1])!]
            } else {
                return str
            }
        } else if let dict = data as? NSDictionary {
            let newDict = NSMutableDictionary(dictionary: dict)
            
            for (key, value) in dict {
                newDict[key as! NSCopying] = _fillInPlaceholders(value)
            }
            
            return newDict
        } else if let arr = data as? [AnyObject] {
            return arr.map({_fillInPlaceholders($0)})
        } else {
            return data
        }
    }
}

extension SnapperPacket {
    private static func findType(binCount: Int, ack: Bool) -> PacketType {
        switch binCount {
        case 0 where !ack:
            return PacketType.Event
        case 0 where ack:
            return PacketType.Ack
        case _ where !ack:
            return PacketType.BinaryEvent
        case _ where ack:
            return PacketType.BinaryAck
        default:
            return PacketType.Error
        }
    }
    
    static func packetFromEmit(items: [AnyObject], id: Int, nsp: String, ack: Bool) -> SnapperPacket {
        let (parsedData, binary) = deconstructData(items)
        let packet = SnapperPacket(type: findType(binary.count, ack: ack), data: parsedData,
            id: id, nsp: nsp, placeholders: -1, binary: binary)
        
        return packet
    }
}

private extension SnapperPacket {
    static func shred(data: AnyObject, inout binary: [NSData]) -> AnyObject {
        if let bin = data as? NSData {
            let placeholder = ["_placeholder": true, "num": binary.count]
            
            binary.append(bin)
            
            return placeholder
        } else if let arr = data as? [AnyObject] {
            return arr.map({shred($0, binary: &binary)})
        } else if let dict = data as? NSDictionary {
            let mutDict = NSMutableDictionary(dictionary: dict)
            
            for (key, value) in dict {
                mutDict[key as! NSCopying] = shred(value, binary: &binary)
            }
            
            return mutDict
        } else {
            return data
        }
    }
    
    static func deconstructData(data: [AnyObject]) -> ([AnyObject], [NSData]) {
        var binary = [NSData]()
        
        return (data.map({shred($0, binary: &binary)}), binary)
    }
}
