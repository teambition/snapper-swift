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

    public fileprivate(set) var engine: SocketEngineSpec?
    public fileprivate(set) var status = SnapperClietnStatus.notConnected

    public var forceNew = false
    public var nsp = "/"
    public var options: Set<SnapperClientOption>
    public var reconnects = true
    public var reconnectWait = 10
    var session: URLSession
    var subscribeURL: String
    var subscribeToken: String

    public var sid: String? {
        return engine?.sid
    }

    fileprivate let emitQueue = DispatchQueue(label: "com.socketio.emitQueue", attributes: [])
    fileprivate let logType = "SocketIOClient"
    fileprivate let parseQueue = DispatchQueue(label: "com.socketio.parseQueue", attributes: [])

    fileprivate var anyHandler: ((SnapperEvent) -> Void)?
    fileprivate var messageHandler: messageCallback?
    fileprivate var currentReconnectAttempt = 0
    fileprivate var handlers = [SnapperEventHandler]()
    fileprivate var connectParams: [String: Any]?
    fileprivate var reconnectTimer: Timer?

    fileprivate(set) var currentAck = -1
    fileprivate(set) var handleQueue = DispatchQueue.main
    fileprivate(set) var reconnectAttempts = -1

    var waitingData = [SnapperPacket]()

    /**
     Type safe way to create a new Snapper. opts can be omitted
     */
    public init(socketURL: String, options: Set<SnapperClientOption> = [], subscribeURL: String = "", subscribeToken: String = "") {
        self.options = options
        self.session = URLSession.shared
        self.subscribeURL = subscribeURL
        self.subscribeToken = subscribeToken
        if socketURL["https://"].matches().count != 0 {
            self.options.insertIgnore(.secure(true))
        }

        self.socketURL = socketURL["https?://"] ~= ""

        for option in options {
            switch option {
            case .connectParams(let params):
                connectParams = params
            case .reconnects(let reconnects):
                self.reconnects = reconnects
            case .reconnectAttempts(let attempts):
                reconnectAttempts = attempts
            case .reconnectWait(let wait):
                reconnectWait = abs(wait)
            case .nsp(let nsp):
                self.nsp = nsp
            case .log(let log):
                DefaultSocketLogger.Logger.isLog = log
            case .logger(let logger):
                DefaultSocketLogger.Logger = logger
            case .handleQueue(let queue):
                handleQueue = queue
            case .forceNew(let force):
                forceNew = force
            default:
                continue
            }
        }

        self.options.insertIgnore(.path("/socket.io"))

        super.init()
    }

    deinit {
        DefaultSocketLogger.Logger.log("Client is being deinit", type: logType)
        engine?.close()
    }

    fileprivate func addEngine() -> SocketEngine {
        DefaultSocketLogger.Logger.log("Adding engine", type: logType)

        let newEngine = SocketEngine(client: self, url: socketURL, options: options )

        engine = newEngine
        return newEngine
    }

    fileprivate func clearReconnectTimer() {
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
    public func connect(timeoutAfter: Int,
        withTimeoutHandler handler: (() -> Void)?) {
            assert(timeoutAfter >= 0, "Invalid timeout: \(timeoutAfter)")

            guard status != .connected else {
                DefaultSocketLogger.Logger.log("Tried connecting on an already connected socket",
                    type: logType)
                return
            }

            status = .connecting

            if engine == nil || forceNew {
                addEngine().open(connectParams)
            } else {
                engine?.open(connectParams)
            }

            guard timeoutAfter != 0 else { return }

            let time = DispatchTime.now() + Double(Int64(timeoutAfter) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)

            handleQueue.asyncAfter(deadline: time) {[weak self] in
                if let this = self, this.status != .connected {
                    this.status = .closed
                    this.engine?.close()

                    handler?()
                }
            }
    }

    public func didConnect() {
        DefaultSocketLogger.Logger.log("Socket connected", type: logType)
        status = .connected
        currentReconnectAttempt = 0
        clearReconnectTimer()

        // Don't handle as internal because something crazy could happen where
        // we disconnect before it's handled
        handleEvent("connect", data: [], isInternalMessage: false)
    }

    func didDisconnect(_ reason: String) {
        guard status != .closed else {
            return
        }

        DefaultSocketLogger.Logger.log("Disconnected: %@", type: logType, args: reason)

        status = .closed
        reconnects = false

        // Make sure the engine is actually dead.
        engine?.close()
        handleEvent("disconnect", data: [reason], isInternalMessage: true)
    }

    /// error
    public func didError(_ reason: Any) {
        DefaultSocketLogger.Logger.error("%@", type: logType, args: reason)

        handleEvent("error", data: reason as? [Any] ?? [reason],
            isInternalMessage: true)
    }

    /**
     Same as close
     */
    public func disconnect() {
        close()
    }

    public func didReceiveMessage(_ message: SnapperMessage) {
        if let handle = messageHandler {
            handle(message)
        }
    }

    public func engineDidClose(_ reason: String) {
        waitingData.removeAll()

        if status == .closed || !reconnects {
            didDisconnect(reason)
        } else if status != .reconnecting {
            status = .reconnecting
            handleEvent("reconnect", data: [reason], isInternalMessage: true)
            tryReconnect()
        }
    }

    /**
     Causes an event to be handled. Only use if you know what you're doing.
     */
    public func handleEvent(_ event: String, data: [Any], isInternalMessage: Bool,
        withAck ack: Int = -1) {
            guard status == .connected || isInternalMessage else {
                return
            }

            DefaultSocketLogger.Logger.log("Handling event: %@ with data: %@", type: logType, args: event, data )

            handleQueue.async {
                self.anyHandler?(SnapperEvent(event: event, items: data as NSArray?))

                for handler in self.handlers where handler.event == event {
                    handler.executeCallback(data)
                }
            }

    }

    /**
     Removes handler(s)
     */
    public func off(_ event: String) {
        DefaultSocketLogger.Logger.log("Removing handler for event: %@", type: logType, args: event)

        handlers = handlers.filter { $0.event != event }
    }

    /**
     Removes a handler with the specified UUID gotten from an `on` or `once`
     */
    public func off(id: UUID) {
        DefaultSocketLogger.Logger.log("Removing handler with id: %@", type: logType, args: id)

        handlers = handlers.filter { $0.id as UUID != id }
    }

    /**
     Adds a handler for an event.
     Returns: A unique id for the handler
     */
    @discardableResult
    public func on(_ event: String, callback: @escaping NormalCallback) -> UUID {
        DefaultSocketLogger.Logger.log("Adding handler for event: %@", type: logType, args: event)

        let handler = SnapperEventHandler(event: event, id: UUID(), callback: callback)
        handlers.append(handler)

        return handler.id
    }

    public func message(_ callback: messageCallback?) {
        messageHandler = callback
    }

    /**
     Adds a handler that will be called on every event.
     */
    public func onAny(_ handler: @escaping (SnapperEvent) -> Void) {
        anyHandler = handler
    }

    public func parseSocketMessage(_ msg: String) {
        parseQueue.async {
            SnapperParser.parseSocketMessage(msg, socket: self)
        }
    }

    public func parseBinaryData(_ data: Data) {

    }

    /**
     replay

     - parameter id: message id
     */
    public func replay(_ id: Any) {

        guard status == .connected else {
            handleEvent("error", data: ["Tried emitting when not connected"], isInternalMessage: true)
            return
        }

        let dict = ["id":id, "result":"OK", "jsonrpc":"2.0"] as [String : Any]
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [])
        let json = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as! String
        engine?.write(json, withType: .message, withData: [])
    }


    /**
     join the project to receive the project notification
     */
    public func join(_ projectID: String) {
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


    func joinRequest(_ projectID: String) {
        let url = URL(string: "\(self.subscribeURL)/api/projects/\(projectID)/subscribe")!
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        let params = ["consumerId":self.sid!]
        request.httpBody = try! JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
        request.addValue("OAuth2 \(self.subscribeToken)", forHTTPHeaderField: "Authorization")
        let dataTask = session.dataTask(with: (request as URLRequest), completionHandler: { (data, response, error) -> Void in
        })
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
        handlers.removeAll(keepingCapacity: false)
    }

    fileprivate func tryReconnect() {
        if reconnectTimer == nil {
            DefaultSocketLogger.Logger.log("Starting reconnect", type: logType)

            status = .reconnecting

            DispatchQueue.main.async {
                self.reconnectTimer = Timer.scheduledTimer(timeInterval: Double(self.reconnectWait),
                    target: self, selector: #selector(SnapperClient._tryReconnect), userInfo: nil, repeats: true)
            }
        }
    }

    @objc fileprivate func _tryReconnect() {
        if status == .connected {
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

        currentReconnectAttempt += 1
        connect()
    }
}

// Test extensions
extension SnapperClient {
    var testHandlers: [SnapperEventHandler] {
        return handlers
    }

    func setTestable() {
        status = .connected
    }

    func setTestEngine(_ engine: SocketEngineSpec?) {
        self.engine = engine
    }
}
