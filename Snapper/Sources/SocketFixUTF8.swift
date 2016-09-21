//
//  SocketFixUTF8.swift
//  snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

func fixDoubleUTF8(_ string: String) -> String {
    if let utf8 = string.data(using: String.Encoding.isoLatin1),
        let latin1 = NSString(data: utf8, encoding: String.Encoding.utf8.rawValue) {
            return latin1 as String
    } else {
        return string
    }
}

func doubleEncodeUTF8(_ string: String) -> String {
    if let latin1 = string.data(using: String.Encoding.utf8),
        let utf8 = NSString(data: latin1, encoding: String.Encoding.isoLatin1.rawValue) {
            return utf8 as String
    } else {
        return string
    }
}
