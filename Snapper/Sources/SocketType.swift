//
//  SocketType.swift
//  snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

public typealias AckCallback = ([Any]) -> Void
public typealias NormalCallback = (Any) -> Void
public typealias messageCallback = ((SnapperMessage) -> Void)
public typealias RefreshTokenCallback = (String) -> Void
public typealias OnAckCallback = (_ timeoutAfter: UInt64, _ callback: AckCallback) -> Void

enum Either<E, V> {
    case left(E)
    case right(V)
}
