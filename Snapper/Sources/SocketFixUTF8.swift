//
//  SocketFixUTF8.swift
//  snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

import Foundation

func fixDoubleUTF8(string: String) -> String {
    if let utf8 = string.dataUsingEncoding(NSISOLatin1StringEncoding),
        latin1 = NSString(data: utf8, encoding: NSUTF8StringEncoding) {
            return latin1 as String
    } else {
        return string
    }
}

func doubleEncodeUTF8(string: String) -> String {
    if let latin1 = string.dataUsingEncoding(NSUTF8StringEncoding),
        utf8 = NSString(data: latin1, encoding: NSISOLatin1StringEncoding) {
            return utf8 as String
    } else {
        return string
    }
}