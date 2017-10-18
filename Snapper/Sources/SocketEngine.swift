//
//  SocketEngine.swift
//  snapper-swift
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

public final class SocketEngine: NSObject, SocketEngineSpec, WebSocketDelegate {

    public fileprivate(set) var sid = ""
    public fileprivate(set) var cookies: [HTTPCookie]?
    public fileprivate(set) var socketPath = "/engine.io"
    public fileprivate(set) var urlPolling = ""
    public fileprivate(set) var urlWebSocket = ""
    public fileprivate(set) var ws: WebSocket?

    public weak var client: SocketEngineClient?

    fileprivate weak var sessionDelegate: URLSessionDelegate?

    fileprivate typealias Probe = (msg: String, type: SocketEnginePacketType, data: [Data])
    fileprivate typealias ProbeWaitQueue = [Probe]

    fileprivate let allowedCharacterSet = CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[]\" {}").inverted
    fileprivate let emitQueue = DispatchQueue(label: "com.socketio.engineEmitQueue", attributes: [])
    fileprivate let handleQueue = DispatchQueue(label: "com.socketio.engineHandleQueue", attributes: [])
    fileprivate let logType = "SocketEngine"
    fileprivate let parseQueue = DispatchQueue(label: "com.socketio.engineParseQueue", attributes: [])
    fileprivate let url: String

    fileprivate var connectParams: [String: Any]?
    fileprivate var closed = false
    fileprivate var extraHeaders: [String: String]?
    fileprivate var fastUpgrade = false
    fileprivate var forcePolling = false
    fileprivate var forceWebsockets = false
    fileprivate var invalidated = false
    fileprivate var pingInterval: Double?
    fileprivate var pingTimer: Timer?
    fileprivate var pingTimeout = 0.0 {
        didSet {
            pongsMissedMax = Int(pingTimeout / (pingInterval ?? 25))
        }
    }
    fileprivate var pongsMissed = 0
    fileprivate var pongsMissedMax = 0
    fileprivate var postWait = [String]()
    fileprivate var probing = false
    fileprivate var probeWait = ProbeWaitQueue()
    fileprivate var secure = false
    fileprivate var selfSigned = false
    fileprivate var session: URLSession?
    fileprivate var voipEnabled = false
    fileprivate var waitingForPoll = false
    fileprivate var waitingForPost = false
    fileprivate var websocketConnected = false
    fileprivate(set) var connected = false
    fileprivate(set) var polling = true
    fileprivate(set) var websocket = false

    public init(client: SocketEngineClient, url: String, options: Set<SnapperClientOption>) {
        self.client = client
        self.url = url

        for option in options {
            switch option {
            case .sessionDelegate(let delegate):
                sessionDelegate = delegate
            case .forcePolling(let force):
                forcePolling = force
            case .forceWebsockets(let force):
                forceWebsockets = force
            case .cookies(let cookies):
                self.cookies = cookies
            case .path(let path):
                socketPath = path
            case .extraHeaders(let headers):
                extraHeaders = headers
            case .voipEnabled(let enable):
                voipEnabled = enable
            case .secure(let secure):
                self.secure = secure
            case .selfSigned(let selfSigned):
                self.selfSigned = selfSigned
            default:
                continue
            }
        }
    }

    public convenience init(client: SocketEngineClient, url: String, options: NSDictionary?) {
        self.init(client: client, url: url,
            options: Set<SnapperClientOption>.NSDictionaryToSocketOptionsSet(options ?? [:]))
    }

    deinit {
        DefaultSocketLogger.Logger.log("Engine is being deinit", type: logType)
        closed = true
        stopPolling()
    }

    fileprivate func checkAndHandleEngineError(_ msg: String) {
        guard let stringData = msg.data(using: String.Encoding.utf8,
            allowLossyConversion: false) else { return }

        do {
            if let dict = try JSONSerialization.jsonObject(with: stringData,
                options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary {
                    guard let code = dict["code"] as? Int else { return }
                    guard let error = dict["message"] as? String else { return }

                    switch code {
                    case 0: // Unknown transport
                        logAndError(error)
                    case 1: // Unknown sid. clear and retry connect
                        sid = ""
                        open(connectParams)
                    case 2: // Bad handshake request
                        logAndError(error)
                    case 3: // Bad request
                        logAndError(error)
                    default:
                        logAndError(error)
                    }
            }
        } catch {
            logAndError("Got unknown error from server")
        }
    }

    fileprivate func checkIfMessageIsBase64Binary(_ message: String) -> Bool {
        if message.hasPrefix("b4") {
            // binary in base64 string
            let noPrefix = message[message.index(message.startIndex, offsetBy: 2)..<message.endIndex]

            if let data = Data(base64Encoded: String(noPrefix), options: .ignoreUnknownCharacters) {
                    client?.parseBinaryData(data)
            }

            return true
        } else {
            return false
        }
    }

    public func close() {
        DefaultSocketLogger.Logger.log("Engine is being closed.", type: logType)

        pingTimer?.invalidate()
        closed = true
        connected = false

        if websocket {
            sendWebSocketMessage("", withType: .close)
        } else {
            sendPollMessage("", withType: .close)
        }

        ws?.disconnect()
        stopPolling()
        client?.engineDidClose("Disconnect")
    }

    fileprivate func createBinaryDataForSend(_ data: Data) -> Either<NSMutableData, String> {
        if websocket {
            var byteArray = [UInt8](repeating: 0x0, count: 1)
            byteArray[0] = 4
            let mutData = NSMutableData(bytes: &byteArray, length: 1)

            mutData.append(data)

            return .left(mutData)
        } else {
            let str = "b4" + data.base64EncodedString(options: .lineLength64Characters)

            return .right(str)
        }
    }

    fileprivate func createURLs(_ params: [String: Any]?) -> (String, String) {
        if client == nil {
            return ("", "")
        }

        let socketURL = "\(url)\(socketPath)/?transport="
        var urlPolling: String
        var urlWebSocket: String

        if secure {
            urlPolling = "https://" + socketURL + "polling"
            urlWebSocket = "wss://" + socketURL + "websocket"
        } else {
            urlPolling = "http://" + socketURL + "polling"
            urlWebSocket = "ws://" + socketURL + "websocket"
        }

        if params != nil {
            for (key, value) in params! {
                let keyEsc = key.addingPercentEncoding(
                    withAllowedCharacters: allowedCharacterSet)!
                urlPolling += "&\(keyEsc)="
                urlWebSocket += "&\(keyEsc)="

                if value is String {
                    let valueEsc = (value as! String).addingPercentEncoding(
                        withAllowedCharacters: allowedCharacterSet)!
                    urlPolling += "\(valueEsc)"
                    urlWebSocket += "\(valueEsc)"
                } else {
                    urlPolling += "\(value)"
                    urlWebSocket += "\(value)"
                }
            }
        }

        return (urlPolling, urlWebSocket)
    }

    fileprivate func createWebsocketAndConnect(_ connect: Bool) {
        let wsUrl = urlWebSocket + (sid == "" ? "" : "&sid=\(sid)")

        ws = WebSocket(url: URL(string: wsUrl)!)

        if cookies != nil {
            let headers = HTTPCookie.requestHeaderFields(with: cookies!)
            for (key, value) in headers {
                ws?.headers[key] = value
            }
        }

        if extraHeaders != nil {
            for (headerName, value) in extraHeaders! {
                ws?.headers[headerName] = value
            }
        }

        ws?.callbackQueue = handleQueue
        ws?.voipEnabled = voipEnabled
        ws?.delegate = self
        ws?.disableSSLCertValidation = selfSigned

        if connect {
            ws?.connect()
        }
    }

    fileprivate func doFastUpgrade() {
        if waitingForPoll {
            DefaultSocketLogger.Logger.error("Outstanding poll when switched to WebSockets," +
                "we'll probably disconnect soon. You should report this.", type: logType)
        }

        sendWebSocketMessage("", withType: .upgrade, datas: nil)
        websocket = true
        polling = false
        fastUpgrade = false
        probing = false
        flushProbeWait()
    }

    fileprivate func flushProbeWait() {
        DefaultSocketLogger.Logger.log("Flushing probe wait", type: logType)

        emitQueue.async {
            for waiter in self.probeWait {
                self.write(waiter.msg, withType: waiter.type, withData: waiter.data)
            }

            self.probeWait.removeAll(keepingCapacity: false)

            if self.postWait.count != 0 {
                self.flushWaitingForPostToWebSocket()
            }
        }
    }

    fileprivate func handleClose(_ reason: String) {
        client?.engineDidClose(reason)
    }

    fileprivate func handleMessage(_ message: String) {
        client?.parseSocketMessage(message)
    }

    fileprivate func handleNOOP() {
        doPoll()
    }

    fileprivate func handleOpen(_ openData: String) {
        let mesData = openData.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        do {
            let json = try JSONSerialization.jsonObject(with: mesData,
                options: JSONSerialization.ReadingOptions.allowFragments) as? NSDictionary
            if let sid = json?["sid"] as? String {
                let upgradeWs: Bool

                self.sid = sid
                connected = true

                if let upgrades = json?["upgrades"] as? [String] {
                    upgradeWs = upgrades.filter {$0 == "websocket"}.count != 0
                } else {
                    upgradeWs = false
                }

                if let pingInterval = json?["pingInterval"] as? Double, let pingTimeout = json?["pingTimeout"] as? Double {
                    self.pingInterval = pingInterval / 1000.0
                    self.pingTimeout = pingTimeout / 1000.0
                }

                if !forcePolling && !forceWebsockets && upgradeWs {
                    createWebsocketAndConnect(true)
                }
                client?.didConnect()
            }
        } catch {
            DefaultSocketLogger.Logger.error("Error parsing open packet", type: logType)
            return
        }

        startPingTimer()

        if !forceWebsockets {
            doPoll()
        }
    }

    fileprivate func handlePong(_ pongMessage: String) {
        pongsMissed = 0

        // We should upgrade
        if pongMessage == "3probe" {
            upgradeTransport()
        }
    }

    // A poll failed, tell the client about it
    fileprivate func handlePollingFailed(_ reason: String) {
        connected = false
        ws?.disconnect()
        pingTimer?.invalidate()
        waitingForPoll = false
        waitingForPost = false

        if !closed {
            client?.didError(reason)
            client?.engineDidClose(reason)
        }
    }

    fileprivate func logAndError(_ error: String) {
        DefaultSocketLogger.Logger.error(error, type: logType)
        client?.didError(error)
    }

    public func open(_ opts: [String: Any]? = nil) {
        connectParams = opts

        if connected {
            DefaultSocketLogger.Logger.error("Tried to open while connected", type: logType)
            client?.didError("Tried to open engine while connected")

            return
        }

        DefaultSocketLogger.Logger.log("Starting engine", type: logType)
        DefaultSocketLogger.Logger.log("Handshaking", type: logType)

        resetEngine()

        (urlPolling, urlWebSocket) = createURLs(opts)

        if forceWebsockets {
            polling = false
            websocket = true
            createWebsocketAndConnect(true)
            return
        }

        let reqPolling = NSMutableURLRequest(url: URL(string: urlPolling + "&b64=1")!)

        if cookies != nil {
            let headers = HTTPCookie.requestHeaderFields(with: cookies!)
            reqPolling.allHTTPHeaderFields = headers
        }

        if let extraHeaders = extraHeaders {
            for (headerName, value) in extraHeaders {
                reqPolling.setValue(value, forHTTPHeaderField: headerName)
            }
        }

        doLongPoll(reqPolling as URLRequest)
    }

    fileprivate func parseEngineData(_ data: Data) {
        DefaultSocketLogger.Logger.log("Got binary data: %@", type: "SocketEngine", args: data)

        client?.parseBinaryData(data.subdata(in: 1..<data.endIndex))
    }

    fileprivate func parseEngineMessage(_ message: String, fromPolling: Bool) {
        if fromPolling {
            DefaultSocketLogger.Logger.log("Got message: %@  from polling", type: logType, args: message)
        } else {
            DefaultSocketLogger.Logger.log("Got message: %@ from ws", type: logType, args: message)
        }

        let reader = SocketStringReader(message: message)
        let fixedString: String

        guard let type = SocketEnginePacketType(rawValue: Int(reader.currentCharacter) ?? -1) else {
            if !checkIfMessageIsBase64Binary(message) {
                checkAndHandleEngineError(message)
            }

            return
        }

        if fromPolling && type != .noop {
            fixedString = fixDoubleUTF8(message)
        } else {
            fixedString = message
        }

        switch type {
        case .message:
            handleMessage(String(fixedString.characters.dropFirst()))
        case .noop:
            handleNOOP()
        case .pong:
            handlePong(fixedString)
        case .open:
            handleOpen(String(fixedString.characters.dropFirst()))
        case .close:
            handleClose(fixedString)
        default:
            DefaultSocketLogger.Logger.log("Got unknown packet type", type: logType)
        }
    }

    fileprivate func probeWebSocket() {
        if websocketConnected {
            sendWebSocketMessage("probe", withType: .ping)
        }
    }


    fileprivate func resetEngine() {
        let queue = OperationQueue()
        queue.underlyingQueue = handleQueue
        
        closed = false
        connected = false
        fastUpgrade = false
        polling = true
        probing = false
        invalidated = false
        session = URLSession(configuration: .default,
            delegate: sessionDelegate,
            delegateQueue: queue)
        sid = ""
        waitingForPoll = false
        waitingForPost = false
        websocket = false
        websocketConnected = false
    }

    /// Send an engine message (4)
    public func send(_ msg: String, withData datas: [Data]) {
        if probing {
            probeWait.append((msg, .message, datas))
        } else {
            write(msg, withType: .message, withData: datas)
        }
    }

    @objc fileprivate func sendPing() {
        //Server is not responding
        if pongsMissed > pongsMissedMax {
            pingTimer?.invalidate()
            client?.engineDidClose("Ping timeout")
            return
        }

        pongsMissed += 1
        write("", withType: .ping, withData: [])
    }

    // Starts the ping timer
    fileprivate func startPingTimer() {
        if let pingInterval = pingInterval {
            pingTimer?.invalidate()
            pingTimer = nil

            DispatchQueue.main.async {
                self.pingTimer = Timer.scheduledTimer(timeInterval: pingInterval, target: self,
                    selector: #selector(SocketEngine.sendPing), userInfo: nil, repeats: true)
            }
        }
    }

    fileprivate func upgradeTransport() {
        if websocketConnected {
            DefaultSocketLogger.Logger.log("\(Thread.current) Upgrading transport to WebSockets", type: logType)

            fastUpgrade = true
            //sendPollMessage("", withType: .noop)
            // After this point, we should not send anymore polling messages
        }
    }

    /**
     Write a message, independent of transport.
     */
    public func write(_ msg: String, withType type: SocketEnginePacketType, withData data: [Data]) {
        emitQueue.async {
            if self.connected {
                if self.websocket {
                    DefaultSocketLogger.Logger.log("Writing ws: %@ has data: %@",
                        type: self.logType, args: msg, data.count != 0)
                    self.sendWebSocketMessage(msg, withType: type, datas: data)
                } else {
                    DefaultSocketLogger.Logger.log("Writing poll: %@ has data: %@",
                        type: self.logType, args: msg, data.count != 0)
                    self.sendPollMessage(msg, withType: type, datas: data)
                }
            }
        }
    }
}

// Polling methods
extension SocketEngine {
    fileprivate func addHeaders(for req: URLRequest) -> URLRequest {
        var req = req
        
        if cookies != nil {
            let headers = HTTPCookie.requestHeaderFields(with: cookies!)
            req.allHTTPHeaderFields = headers
        }
        
        if extraHeaders != nil {
            for (headerName, value) in extraHeaders! {
                req.setValue(value, forHTTPHeaderField: headerName)
            }
        }
        
        return req
    }

    fileprivate func doPoll() {
        if websocket || waitingForPoll || !connected || closed {
            return
        }
        
        guard let pollingURL = URL(string: urlPolling + "&sid=\(sid)&b64=1") else {
            return
        }

        waitingForPoll = true
        var req = URLRequest(url: pollingURL)

        req = addHeaders(for: req)
        doLongPoll(req)
    }

    fileprivate func doRequest(_ req: URLRequest, withCallback callback: @escaping (Data?, URLResponse?, Error?) -> Void) {
        if !polling || closed || invalidated {
            DefaultSocketLogger.Logger.error("Tried to do polling request when not supposed to", type: logType)
            return
        }

        DefaultSocketLogger.Logger.log("Doing polling request", type: logType)
        
        var req = req
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session?.dataTask(with: req, completionHandler: callback).resume()
    }

    fileprivate func doLongPoll(_ req: URLRequest) {
        doRequest(req) {[weak self] data, res, err in
            guard let this = self, this.polling else { return }
            DefaultSocketLogger.Logger.log("Got polling response", type: this.logType)

            if err != nil || data == nil {
                DefaultSocketLogger.Logger.error(err?.localizedDescription ?? "Error", type: this.logType)

                if this.polling {
                    this.handlePollingFailed(err?.localizedDescription ?? "Error")
                }

                return
            }

            if let str = String(data: data!, encoding: String.Encoding.utf8) {
                this.parseQueue.async {
                    this.parsePollingMessage(str)
                }
            }

            this.waitingForPoll = false

            if this.fastUpgrade {
                this.doFastUpgrade()
            } else if !this.closed && this.polling {
                this.doPoll()
            }
        }
    }

    fileprivate func flushWaitingForPost() {
        if postWait.count == 0 || !connected {
            return
        } else if websocket {
            flushWaitingForPostToWebSocket()
            return
        }

        var postStr = ""

        for packet in postWait {
            let len = packet.characters.count

            postStr += "\(len):\(packet)"
        }

        postWait.removeAll(keepingCapacity: false)

        var req = URLRequest(url: URL(string: urlPolling + "&sid=\(sid)")!)

        req = addHeaders(for: req)

        req.httpMethod = "POST"
        req.setValue("text/plain; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        let postData = postStr.data(using: String.Encoding.utf8,
            allowLossyConversion: false)!

        req.httpBody = postData
        req.setValue(String(postData.count), forHTTPHeaderField: "Content-Length")

        waitingForPost = true

        DefaultSocketLogger.Logger.log("POSTing: %@", type: logType, args: postStr)

        doRequest(req) {[weak self] data, res, err in
            guard let this = self else {return}
            DefaultSocketLogger.Logger.log("Got polling response for flushWaitingForPost", type: this.logType)

            if err != nil {
                DefaultSocketLogger.Logger.error(err?.localizedDescription ?? "Error", type: this.logType)

                if this.polling {
                    this.handlePollingFailed(err?.localizedDescription ?? "Error")
                }

                return
            }

            this.waitingForPost = false

            this.emitQueue.async {
                if !this.fastUpgrade {
                    this.flushWaitingForPost()
                    this.doPoll()
                }
            }
        }
    }

    // We had packets waiting for send when we upgraded
    // Send them raw
    fileprivate func flushWaitingForPostToWebSocket() {
        guard let ws = self.ws else { return }

        for msg in postWait {
            ws.write(string: fixDoubleUTF8(msg))
        }

        postWait.removeAll(keepingCapacity: true)
    }

    func parsePollingMessage(_ str: String) {
        guard str.characters.count != 1 else {
            return
        }

        var reader = SocketStringReader(message: str)

        while reader.hasNext {
            if let n = Int(reader.readUntilStringOccurence(string: ":")) {
                let str = reader.read(readLength: n)

                handleQueue.async {
                    self.parseEngineMessage(str, fromPolling: true)
                }
            } else {
                handleQueue.async {
                    self.parseEngineMessage(str, fromPolling: true)
                }
                break
            }
        }
    }

    /// Send polling message.
    /// Only call on emitQueue
    fileprivate func sendPollMessage(_ message: String, withType type: SocketEnginePacketType,
        datas: [Data]? = nil) {
            DefaultSocketLogger.Logger.log("Sending poll: %@ as type: %@", type: logType, args: message, type.rawValue)
            let fixedMessage = doubleEncodeUTF8(message)
            let strMsg = "\(type.rawValue)\(fixedMessage)"

            postWait.append(strMsg)

            for data in datas ?? [] {
                if case let .right(bin) = createBinaryDataForSend(data) {
                    postWait.append(bin)
                }
            }

            if !waitingForPost {
                flushWaitingForPost()
            }
    }

    fileprivate func stopPolling() {
        invalidated = true
        session?.finishTasksAndInvalidate()
    }
}

// WebSocket methods
extension SocketEngine {
    /// Send message on WebSockets
    /// Only call on emitQueue
    fileprivate func sendWebSocketMessage(_ str: String, withType type: SocketEnginePacketType,
        datas: [Data]? = nil) {
            DefaultSocketLogger.Logger.log("Sending ws: %@ as type: %@", type: logType, args: str, type.rawValue)

            ws?.write(string: "\(type.rawValue)\(str)")

            for data in datas ?? [] {
                if case let .left(bin) = createBinaryDataForSend(data) {
                    ws?.write(data: bin as Data)
                }
            }
    }

    // Delagate methods

    public func websocketDidConnect(socket: WebSocket) {
        websocketConnected = true

        if !forceWebsockets {
            probing = true
            probeWebSocket()
        } else {
            connected = true
            probing = false
            polling = false
        }
    }

    public func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        websocketConnected = false
        probing = false

        if closed {
            client?.engineDidClose("Disconnect")
            return
        }

        if websocket {
            pingTimer?.invalidate()
            connected = false
            websocket = false

            let reason = error?.localizedDescription ?? "Socket Disconnected"

            if error != nil {
                client?.didError(reason)
            }

            client?.engineDidClose(reason)
        } else {
            flushProbeWait()
        }
    }

    public func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        parseEngineMessage(text, fromPolling: false)
    }

    public func websocketDidReceiveData(socket: WebSocket, data: Data) {
        parseEngineData(data)
    }
}
