//
//  SnapperParser.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

class SnapperParser {

    fileprivate static func handlePacket(_ pack: SnapperPacket, withSocket socket: SnapperClient) {
        switch pack.type {
        case .event:
            socket.handleEvent(pack.event, data: pack.args ?? [],
                isInternalMessage: false, withAck: pack.id)
        case .disconnect:
            socket.didDisconnect("Got Disconnect")
        case .error:
            socket.didError(pack.data)
        case .message:
            socket.didReceiveMessage(pack.message!)
        default:
            DefaultSocketLogger.Logger.log("Got invalid packet: %@", type: "SocketParser", args: pack.description)
        }
    }

    /// Parses a messsage from the engine. Returning either a string error or a complete SocketPacket
    static func parseString(_ message: String) -> Either<String, SnapperPacket> {
        guard let messageData = message.data(using: String.Encoding.utf8) else {
            return .left("Invalid packet type")
        }
        do {
            var tempArray = [Any]()
            if let json = try JSONSerialization.jsonObject(with: messageData,
                options: JSONSerialization.ReadingOptions.allowFragments) as? NSDictionary {
                var packet = SnapperPacket(type: .message, nsp: "Message")

                guard let id = json["id"] else {
                    return .left("Invalid packet type")
                }

                if let params = json["params"] as? [String] {
                    do {
                        try params.forEach({ (param) in
                            let paramsData = param.data(using: String.Encoding.utf8, allowLossyConversion: false)
                            if let data = paramsData {
                                let paramsArray =  try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                                tempArray.append(paramsArray)
                            }
                        })
                        packet.message = SnapperMessage(id:id, message: "message", items: tempArray as NSArray?)
                        return .right(packet)
                    } catch {
                        return .left("Invalid packet type")
                    }
                } else {
                    return .left("Invalid packet type")
                }
            } else {
                return .left("Invalid packet type")
            }

        } catch {
            DefaultSocketLogger.Logger.error("Error parsing message packet", type: "")
            return .left("Invalid packet type")
        }
    }

    // Parses data for events
    fileprivate static func parseData(_ data: String) -> Either<String, [Any]> {
        let stringData = data.data(using: String.Encoding.utf8, allowLossyConversion: false)
        do {
            if let arr = try JSONSerialization.jsonObject(with: stringData!,
                options: JSONSerialization.ReadingOptions.mutableContainers) as? [AnyObject] {
                    return .right(arr)
            } else {
                return .left("Expected data array")
            }
        } catch {
            return .left("Error parsing data for packet")
        }
    }

    // Parses messages recieved
    static func parseSocketMessage(_ message: String, socket: SnapperClient) {
        guard !message.isEmpty else { return }

        DefaultSocketLogger.Logger.log("Parsing %@", type: "SocketParser", args: message)
        switch parseString(message) {
        case .left(let err):
            DefaultSocketLogger.Logger.error("\(err): %@", type: "SocketParser", args: message as AnyObject)
        case .right(let pack):
            DefaultSocketLogger.Logger.log("Decoded packet as: %@", type: "SocketParser", args: pack.description)
            handlePacket(pack, withSocket: socket)
        }
    }
}
