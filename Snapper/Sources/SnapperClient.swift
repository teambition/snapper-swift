//
//  SnapperClient.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//


import Foundation
import CoreFoundation

public final class SnapperClient: NSObject, SocketEngineClient {
    public let socketURL: String
    
    public private(set) var engine: SocketEngineSpec?
    public private(set) var status = SnapperClietnStatus.NotConnected
    
    public var forceNew = false
    public var nsp = "/"
    public var options: Set<SnapperClientOption>
    public var reconnects = true
    public var reconnectWait = 10
    var session: NSURLSession
    var subscribeURL: String
    var subscribeToken: String
    
    public var sid: String? {
        return engine?.sid
    }
    
    private let emitQueue = dispatch_queue_create("com.socketio.emitQueue", DISPATCH_QUEUE_SERIAL)
    private let logType = "SocketIOClient"
    private let parseQueue = dispatch_queue_create("com.socketio.parseQueue", DISPATCH_QUEUE_SERIAL)
    
    private var anyHandler: ((SnapperEvent) -> Void)?
    private var messageHandler: messageCallback?
    private var currentReconnectAttempt = 0
    private var handlers = [SnapperEventHandler]()
    private var connectParams: [String: AnyObject]?
    private var reconnectTimer: NSTimer?
    
    private(set) var currentAck = -1
    private(set) var handleQueue = dispatch_get_main_queue()
    private(set) var reconnectAttempts = -1
    
    var waitingData = [SnapperPacket]()
    
    /**
     Type safe way to create a new Snapper. opts can be omitted
     */
    public init(socketURL: String, options: Set<SnapperClientOption> = [], subscribeURL: String = "", subscribeToken: String = "") {
        self.options = options
        self.session = NSURLSession.sharedSession()
        self.subscribeURL = subscribeURL
        self.subscribeToken = subscribeToken
        if socketURL["https://"].matches().count != 0 {
            self.options.insertIgnore(.Secure(true))
        }
        
        self.socketURL = socketURL["https?://"] ~= ""
        
        for option in options ?? [] {
            switch option {
            case .ConnectParams(let params):
                connectParams = params
            case .Reconnects(let reconnects):
                self.reconnects = reconnects
            case .ReconnectAttempts(let attempts):
                reconnectAttempts = attempts
            case .ReconnectWait(let wait):
                reconnectWait = abs(wait)
            case .Nsp(let nsp):
                self.nsp = nsp
            case .Log(let log):
                DefaultSocketLogger.Logger.log = log
            case .Logger(let logger):
                DefaultSocketLogger.Logger = logger
            case .HandleQueue(let queue):
                handleQueue = queue
            case .ForceNew(let force):
                forceNew = force
            default:
                continue
            }
        }
        
        self.options.insertIgnore(.Path("/socket.io"))
        
        super.init()
    }
    
    deinit {
        DefaultSocketLogger.Logger.log("Client is being deinit", type: logType)
        engine?.close()
    }
    
    private func addEngine() -> SocketEngine {
        DefaultSocketLogger.Logger.log("Adding engine", type: logType)
        
        let newEngine = SocketEngine(client: self, url: socketURL, options: options ?? [])
        
        engine = newEngine
        return newEngine
    }
    
    private func clearReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    /**
     Closes the socket. Only reopen the same socket if you know what you're doing.
     Will turn off automatic reconnects.
     Pass true to fast if you're closing from a background task
     */
    public func close() {
        DefaultSocketLogger.Logger.log("Closing socket", type: logType)
        
        reconnects = false
        didDisconnect("Closed")
    }
    
    /**
     Connect to the server.
     */
    public func connect() {
        connect(timeoutAfter: 0, withTimeoutHandler: nil)
    }
    
    /**
     Connect to the server. If we aren't connected after timeoutAfter, call handler
     */
    public func connect(timeoutAfter timeoutAfter: Int,
        withTimeoutHandler handler: (() -> Void)?) {
            assert(timeoutAfter >= 0, "Invalid timeout: \(timeoutAfter)")
            
            guard status != .Connected else {
                DefaultSocketLogger.Logger.log("Tried connecting on an already connected socket",
                    type: logType)
                return
            }
            
            status = .Connecting
            
            if engine == nil || forceNew {
                addEngine().open(connectParams)
            } else {
                engine?.open(connectParams)
            }
            
            guard timeoutAfter != 0 else { return }
            
            let time = dispatch_time(DISPATCH_TIME_NOW, Int64(timeoutAfter) * Int64(NSEC_PER_SEC))
            
            dispatch_after(time, handleQueue) {[weak self] in
                if let this = self where this.status != .Connected {
                    this.status = .Closed
                    this.engine?.close()
                    
                    handler?()
                }
            }
    }
    
    public func didConnect() {
        DefaultSocketLogger.Logger.log("Socket connected", type: logType)
        status = .Connected
        currentReconnectAttempt = 0
        clearReconnectTimer()
        
        // Don't handle as internal because something crazy could happen where
        // we disconnect before it's handled
        handleEvent("connect", data: [], isInternalMessage: false)
    }
    
    func didDisconnect(reason: String) {
        guard status != .Closed else {
            return
        }
        
        DefaultSocketLogger.Logger.log("Disconnected: %@", type: logType, args: reason)
        
        status = .Closed
        reconnects = false
        
        // Make sure the engine is actually dead.
        engine?.close()
        handleEvent("disconnect", data: [reason], isInternalMessage: true)
    }
    
    /// error
    public func didError(reason: AnyObject) {
        DefaultSocketLogger.Logger.error("%@", type: logType, args: reason)
        
        handleEvent("error", data: reason as? [AnyObject] ?? [reason],
            isInternalMessage: true)
    }
    
    /**
     Same as close
     */
    public func disconnect() {
        close()
    }
    
    public func didReceiveMessage(message: SnapperMessage) {
        if let handle = messageHandler {
            handle(message)
        }
    }
    
    public func engineDidClose(reason: String) {
        waitingData.removeAll()
        
        if status == .Closed || !reconnects {
            didDisconnect(reason)
        } else if status != .Reconnecting {
            status = .Reconnecting
            handleEvent("reconnect", data: [reason], isInternalMessage: true)
            tryReconnect()
        }
    }
    
    /**
     Causes an event to be handled. Only use if you know what you're doing.
     */
    public func handleEvent(event: String, data: [AnyObject], isInternalMessage: Bool,
        withAck ack: Int = -1) {
            guard status == .Connected || isInternalMessage else {
                return
            }
            
            DefaultSocketLogger.Logger.log("Handling event: %@ with data: %@", type: logType, args: event, data ?? "")
            
            dispatch_async(handleQueue) {
                self.anyHandler?(SnapperEvent(event: event, items: data))
                
                for handler in self.handlers where handler.event == event {
                    handler.executeCallback(data)
                }
            }
            
    }
    
    /**
     Removes handler(s)
     */
    public func off(event: String) {
        DefaultSocketLogger.Logger.log("Removing handler for event: %@", type: logType, args: event)
        
        handlers = handlers.filter { $0.event != event }
    }
    
    /**
     Removes a handler with the specified UUID gotten from an `on` or `once`
     */
    public func off(id id: NSUUID) {
        DefaultSocketLogger.Logger.log("Removing handler with id: %@", type: logType, args: id)
        
        handlers = handlers.filter { $0.id != id }
    }
    
    /**
     Adds a handler for an event.
     Returns: A unique id for the handler
     */
    public func on(event: String, callback: NormalCallback) -> NSUUID {
        DefaultSocketLogger.Logger.log("Adding handler for event: %@", type: logType, args: event)
        
        let handler = SnapperEventHandler(event: event, id: NSUUID(), callback: callback)
        handlers.append(handler)
        
        return handler.id
    }
    
    public func message(callback: messageCallback?) {
        messageHandler = callback
    }
    
    /**
     Adds a handler that will be called on every event.
     */
    public func onAny(handler: (SnapperEvent) -> Void) {
        anyHandler = handler
    }
    
    public func parseSocketMessage(msg: String) {
        dispatch_async(parseQueue) {
            SnapperParser.parseSocketMessage(msg, socket: self)
        }
    }
    
    public func parseBinaryData(data: NSData) {
        
    }
    
    /**
     replay
     
     - parameter id: message id
     */
    public func replay(id: Int) {
        
        guard status == .Connected else {
            handleEvent("error", data: ["Tried emitting when not connected"], isInternalMessage: true)
            return
        }
        
        let dict = ["id":id,"result":"OK","jsonrpc":"2.0"]
        let data = try! NSJSONSerialization.dataWithJSONObject(dict, options: [])
        let json = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
        engine?.write(json, withType: .Message, withData: [])
    }

    
    /**
     join the project to receive the project notification
     */
    public func join(projectID: String) {
        guard self.subscribeToken != ""else {
            DefaultSocketLogger.Logger.log("subscribeToken must not be empty", type: logType)
            return
        }
        guard self.subscribeURL != "" else {
            DefaultSocketLogger.Logger.log("subscribeURL must not be empty", type: logType)
            return
        }
        joinRequest(projectID)
    }
    

    func joinRequest(projectID: String) {
        let url = NSURL(string: "\(self.subscribeURL)/api/projects/\(projectID)/subscribe")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        let params = ["consumerId":self.sid!]
        request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(params, options: .PrettyPrinted)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(params, options: .PrettyPrinted)
        request.addValue("OAuth2 \(self.subscribeToken)", forHTTPHeaderField: "Authorization")
        let dataTask = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
        }
        dataTask.resume()
    }

    /**
     Tries to reconnect to the server.
     */
    public func reconnect() {
        tryReconnect()
    }
    
    /**
     Removes all handlers.
     Can be used after disconnecting to break any potential remaining retain cycles.
     */
    public func removeAllHandlers() {
        handlers.removeAll(keepCapacity: false)
    }
    
    private func tryReconnect() {
        if reconnectTimer == nil {
            DefaultSocketLogger.Logger.log("Starting reconnect", type: logType)
            
            status = .Reconnecting
            
            dispatch_async(dispatch_get_main_queue()) {
                self.reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(Double(self.reconnectWait),
                    target: self, selector: "_tryReconnect", userInfo: nil, repeats: true)
            }
        }
    }
    
    @objc private func _tryReconnect() {
        if status == .Connected {
            clearReconnectTimer()
            
            return
        }
        
        if reconnectAttempts != -1 && currentReconnectAttempt + 1 > reconnectAttempts || !reconnects {
            clearReconnectTimer()
            didDisconnect("Reconnect Failed")
            
            return
        }
        
        DefaultSocketLogger.Logger.log("Trying to reconnect", type: logType)
        handleEvent("reconnectAttempt", data: [reconnectAttempts - currentReconnectAttempt],
            isInternalMessage: true)
        
        currentReconnectAttempt++
        connect()
    }
}

// Test extensions
extension SnapperClient {
    var testHandlers: [SnapperEventHandler] {
        return handlers
    }
    
    func setTestable() {
        status = .Connected
    }
    
    func setTestEngine(engine: SocketEngineSpec?) {
        self.engine = engine
    }
}