//
//  SocketType.swift
//  snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

public typealias AckCallback = ([AnyObject]) -> Void
public typealias NormalCallback = (AnyObject) -> Void
public typealias messageCallback = (SnapperMessage -> Void)
public typealias OnAckCallback = (timeoutAfter: UInt64, callback: AckCallback) -> Void

enum Either<E, V> {
    case Left(E)
    case Right(V)
}
