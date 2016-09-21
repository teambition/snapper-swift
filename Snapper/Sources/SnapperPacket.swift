//
//  SocketPacket.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

struct SnapperPacket {
    fileprivate let placeholders: Int
    fileprivate var currentPlace = 0

    fileprivate static let logType = "SnapperPacket"

    let nsp: String
    let id: Int
    let type: PacketType

    enum PacketType: Int {
        case connect, disconnect, event, ack, error, binaryEvent, binaryAck, message
    }

    var args: [Any]? {
        var arr = data

        if data.count == 0 {
            return nil
        } else {
            if type == .event || type == .binaryEvent {
                arr.remove(at: 0)
                return arr
            } else {
                return arr
            }
        }
    }

    var binary: [Data]
    var data: [Any]
    var message: SnapperMessage?
    var description: String {
        return "SocketPacket {type: \(String(type.rawValue)); data: " +
        "\(String(describing: data)); id: \(id); placeholders: \(placeholders); nsp: \(nsp)}"
    }

    var event: String {
        return data[0] as? String ?? String(describing: data[0])
    }

    var packetString: String {
        return createPacketString()
    }

    init(type: SnapperPacket.PacketType, data: [Any] = [Any](), id: Int = -1,
        nsp: String, placeholders: Int = 0, binary: [Data] = [Data]()) {
            self.data = data
            self.id = id
            self.nsp = nsp
            self.type = type
            self.placeholders = placeholders
            self.binary = binary
    }

    mutating func addData(_ data: Data) -> Bool {
        if placeholders == currentPlace {
            return true
        }

        binary.append(data)
        currentPlace += 1

        if placeholders == currentPlace {
            currentPlace = 0
            return true
        } else {
            return false
        }
    }

    fileprivate func completeMessage(_ message: String, ack: Bool) -> String {
        var restOfMessage = ""

        if data.count == 0 {
            return message + "]"
        }

        for arg in data {
            if arg is NSDictionary || arg is [Any] {
                do {
                    let jsonSend = try JSONSerialization.data(withJSONObject: arg,
                        options: JSONSerialization.WritingOptions(rawValue: 0))
                    let jsonString = NSString(data: jsonSend, encoding: String.Encoding.utf8.rawValue)

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
            restOfMessage.remove(at: restOfMessage.characters.index(before: restOfMessage.endIndex))
        }

        return message + restOfMessage + "]"
    }

    fileprivate func createAck() -> String {
        let msg: String

        if type == PacketType.ack {
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


    fileprivate func createMessageForEvent() -> String {
        let message: String

        if type == PacketType.event {
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

    fileprivate func createPacketString() -> String {
        let str: String

        if type == .event || type == .binaryEvent {
            str = createMessageForEvent()
        } else {
            str = createAck()
        }

        return str
    }

    mutating func fillInPlaceholders() {
        for i in 0..<data.count {
            if let str = data[i] as? String, let num = str["~~(\\d)"].groups() {
                // Fill in binary placeholder with data
                data[i] = binary[Int(num[1])!]
            } else if data[i] is NSDictionary || data[i] is NSArray {
                data[i] = _fillInPlaceholders(data[i])
            }
        }
    }

    fileprivate mutating func _fillInPlaceholders(_ data: Any) -> Any {
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
        } else if let arr = data as? [Any] {
            return arr.map({_fillInPlaceholders($0)})
        } else {
            return data
        }
    }
}

extension SnapperPacket {
    fileprivate static func findType(_ binCount: Int, ack: Bool) -> PacketType {
        switch binCount {
        case 0 where !ack:
            return PacketType.event
        case 0 where ack:
            return PacketType.ack
        case _ where !ack:
            return PacketType.binaryEvent
        case _ where ack:
            return PacketType.binaryAck
        default:
            return PacketType.error
        }
    }

    static func packetFromEmit(_ items: [Any], id: Int, nsp: String, ack: Bool) -> SnapperPacket {
        let (parsedData, binary) = deconstructData(items)
        let packet = SnapperPacket(type: findType(binary.count, ack: ack), data: parsedData,
            id: id, nsp: nsp, placeholders: -1, binary: binary)

        return packet
    }
}

private extension SnapperPacket {
    static func shred(_ data: Any, binary: inout [Data]) -> Any {
        if let bin = data as? Data {
            let placeholder = ["_placeholder": true, "num": binary.count] as [String : Any]

            binary.append(bin)

            return placeholder
        } else if let arr = data as? [Any] {
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

    static func deconstructData(_ data: [Any]) -> ([Any], [Data]) {
        var binary = [Data]()

        return (data.map({shred($0, binary: &binary)}), binary)
    }
}
