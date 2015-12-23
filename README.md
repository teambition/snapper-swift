# Snapper-swift
Snapper-core client by Swift 2.0 for iOS/OS X

[![Build Status](https://travis-ci.org/socketio/socket.io-client-swift.svg?branch=master)](https://travis-ci.org/socketio/socket.io-client-swift)


##Example
```swift
let snapper = SnapperClient(socketURL: "snapper.project.bi/websocket", options: [.Log(true), .ConnectParams(["token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI1NWM4MTdmOGU3MTVmYTk5MmExOTNlOTkiLCJleHAiOjE0NTA5MzYwODd9.Y9gk3d3YTE3loyUxWSxiVJzHjhe12bn5O5qGsuJ89JE"])])

snapper.connect()
        
snapper.on("connect") { (data) -> Void in
    print("connect")
    print(self.snapper.status)
}
        
snapper.on("error") { (data) -> Void in
            
}
        
snapper.on("reconnect") { (data) -> Void in
            
}
        
snapper.message { (message: SnapperMessage) -> Void in
    print(message.items)
    self.snapper.replay(message.id)
}
```

##Features
- Supports engine.io
- Supports Polling and WebSockets
- Supports TLS/SSL

##Installation
Requires Swift 2/Xcode 7

Manually (iOS 7+)
-----------------
1. Copy the Source folder into your Xcode project. (Make sure you add the files to your target(s))
2. If you plan on using this from Objective-C, read [this](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html) on exposing Swift code to Objective-C.

Swift Package Manager
---------------------
Add the project as a dependency to your Package.swift:
```swift
import PackageDescription

let package = Package(
    name: "YourSocketIOProject",
    dependencies: [
        .Package(url: "https://github.com/socketio/socket.io-client-swift", majorVersion: 4)
    ]
)
```

Then import `import SocketIOClientSwift`.

Carthage
-----------------
Add this line to your `Cartfile`:
```
github "teambition/Snapper-swift"
```

Run `carthage update --platform ios,macosx`.

CocoaPods 0.36.0 or later (iOS 8+)
------------------
Create `Podfile` and add `pod 'Socket.IO-Client-Swift'`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

pod 'Snapper-swift'
```

Install pods:

```
$ pod install
```

Import the module:

Swift:
```swift
import Socket_IO_Client_Swift
```


##API
Constructors
-----------
`init(var socketURL: String, options: Set<SocketIOClientOption> = [])` - Creates a new SocketIOClient. opts is a Set of SocketIOClientOption. If your socket.io server is secure, you need to specify `https` in your socketURL.

`convenience init(socketURL: String, options: NSDictionary?)` - Same as above, but meant for Objective-C. See Options on how convert between SocketIOClientOptions and dictionary keys.

Options
-------
All options are a case of SocketIOClientOption. To get the Objective-C Option, convert the name to lowerCamelCase.

```swift
case ConnectParams([String: AnyObject]) // Dictionary whose contents will be passed with the connection.
case Reconnects(Bool) // Whether to reconnect on server lose. Default is `true`
case ReconnectAttempts(Int) // How many times to reconnect. Default is `-1` (infinite tries)
case ReconnectWait(Int) // Amount of time to wait between reconnects. Default is `10`
case ForcePolling(Bool) // `true` forces the client to use xhr-polling. Default is `false`
case ForceNew(Bool) // Will a create a new engine for each connect. Useful if you find a bug in the engine related to reconnects
case ForceWebsockets(Bool) // `true` forces the client to use WebSockets. Default is `false`
case Nsp(String) // The namespace to connect to. Must begin with /. Default is `/`
case Cookies([NSHTTPCookie]) // An array of NSHTTPCookies. Passed during the handshake. Default is nil.
case Log(Bool) // If `true` socket will log debug messages. Default is false.
case Logger(SocketLogger) // Custom logger that conforms to SocketLogger. Will use the default logging otherwise.
case SessionDelegate(NSURLSessionDelegate) // Sets an NSURLSessionDelegate for the underlying engine. Useful if you need to handle self-signed certs. Default is nil.
case Path(String) // If the server uses a custom path. ex: `"/swift"`. Default is `""`
case ExtraHeaders([String: String]) // Adds custom headers to the initial request. Default is nil.
case HandleQueue(dispatch_queue_t) // The dispatch queue that handlers are run on. Default is the main queue.
case VoipEnabled(Bool) // Only use this option if you're using the client with VoIP services. Changes the way the WebSocket is created. Default is false
case Secure(Bool) // If the connection should use TLS. Default is false.
case SelfSigned(Bool) // Sets WebSocket.selfSignedSSL (Don't do this, iOS will yell at you)

```
Methods
-------
1. `on(event: String, callback: NormalCallback) -> NSUUID` - Adds a handler for an event. Items are passed by an array. `ack` can be used to send an ack when one is requested. See example. Returns a unique id for the handler.
2. `once(event: String, callback: NormalCallback) -> NSUUID` - Adds a handler that will only be executed once. Returns a unique id for the handler.
3. `onAny(callback:((event: String, items: AnyObject?)) -> Void)` - Adds a handler for all events. It will be called on any received event.
4. `emit(event: String, _ items: AnyObject...)` - Sends a message. Can send multiple items.
5. `emit(event: String, withItems items: [AnyObject])` - `emit` for Objective-C
6. `emitWithAck(event: String, _ items: AnyObject...) -> (timeoutAfter: UInt64, callback: (NSArray?) -> Void) -> Void` - Sends a message that requests an acknowledgement from the server. Returns a function which you can use to add a handler. See example. Note: The message is not sent until you call the returned function.
7. `emitWithAck(event: String, withItems items: [AnyObject]) -> (UInt64, (NSArray?) -> Void) -> Void` - `emitWithAck` for Objective-C. Note: The message is not sent until you call the returned function.
8. `connect()` - Establishes a connection to the server. A "connect" event is fired upon successful connection.
9. `connect(timeoutAfter timeoutAfter: Int, withTimeoutHandler handler: (() -> Void)?)` - Connect to the server. If it isn't connected after timeoutAfter seconds, the handler is called.
10. `close()` - Closes the socket. Once a socket is closed it should not be reopened.
11. `reconnect()` - Causes the client to reconnect to the server.
12. `joinNamespace()` - Causes the client to join nsp. Shouldn't need to be called unless you change nsp manually.
13. `leaveNamespace()` - Causes the client to leave the nsp and go back to /
14. `off(event: String)` - Removes all event handlers for event.
15. `off(id id: NSUUID)` - Removes the event that corresponds to id.
16. `removeAllHandlers()` - Removes all handlers.

Client Events
------
1. `connect` - Emitted when on a successful connection.
2. `disconnect` - Emitted when the connection is closed.
3. `error` - Emitted on an error.
4. `reconnect` - Emitted when the connection is starting to reconnect.
5. `reconnectAttempt` - Emitted when attempting to reconnect.

##Detailed Example
A more detailed example can be found [here](https://github.com/nuclearace/socket.io-client-swift-example)

##License
MIT
