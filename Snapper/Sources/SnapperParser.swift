//
//  SnapperParser.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

class SnapperParser {
    
    private static func handlePacket(pack: SnapperPacket, withSocket socket: SnapperClient) {
        switch pack.type {
        case .Event:
            socket.handleEvent(pack.event, data: pack.args ?? [],
                isInternalMessage: false, withAck: pack.id)
        case .Disconnect:
            socket.didDisconnect("Got Disconnect")
        case .Error:
            socket.didError(pack.data)
        case .Message:
            socket.didReceiveMessage(pack.message!)
        default:
            DefaultSocketLogger.Logger.log("Got invalid packet: %@", type: "SocketParser", args: pack.description)
        }
    }
    
    /// Parses a messsage from the engine. Returning either a string error or a complete SocketPacket
    static func parseString(message: String) -> Either<String, SnapperPacket> {
        let messageData = message.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        do {
            if let json = try NSJSONSerialization.JSONObjectWithData(messageData,
                options: NSJSONReadingOptions.AllowFragments) as? NSDictionary {
                    var packet = SnapperPacket(type: .Message, nsp: "Message")
                    
                    let id: NSNumber = json["id"] as! NSNumber
                    
                    if let params = json["params"] {
                        let paramsData = params.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
                        let paramsArray =  try NSJSONSerialization.JSONObjectWithData(paramsData, options: .AllowFragments)
                        packet.message = SnapperMessage(id:id.integerValue, message: "message", items: paramsArray as? NSArray)
                        return .Right(packet)
                    } else {
                        return .Left("Invalid packet type")
                    }
            } else {
                return .Left("Invalid packet type")
            }
            
        } catch {
            DefaultSocketLogger.Logger.error("Error parsing message packet", type: "")
            return .Left("Invalid packet type")
        }
    }
    
    // Parses data for events
    private static func parseData(data: String) -> Either<String, [AnyObject]> {
        let stringData = data.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        do {
            if let arr = try NSJSONSerialization.JSONObjectWithData(stringData!,
                options: NSJSONReadingOptions.MutableContainers) as? [AnyObject] {
                    return .Right(arr)
            } else {
                return .Left("Expected data array")
            }
        } catch {
            return .Left("Error parsing data for packet")
        }
    }
    
    // Parses messages recieved
    static func parseSocketMessage(message: String, socket: SnapperClient) {
        guard !message.isEmpty else { return }
        
        DefaultSocketLogger.Logger.log("Parsing %@", type: "SocketParser", args: message)
        switch parseString(message) {
        case .Left(let err):
            DefaultSocketLogger.Logger.error("\(err): %@", type: "SocketParser", args: message)
        case .Right(let pack):
            DefaultSocketLogger.Logger.log("Decoded packet as: %@", type: "SocketParser", args: pack.description)
            handlePacket(pack, withSocket: socket)
        }
    }
}
