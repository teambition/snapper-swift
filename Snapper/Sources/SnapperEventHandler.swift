//
//  SnapperEventHandle.swift
//  Snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

struct SnapperEventHandler {
    let event: String
    let id: UUID
    let callback: NormalCallback

    func executeCallback(_ items: [Any]) {
        callback(items)
    }
}
