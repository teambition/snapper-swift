//
//  SocketStringReader.swift
//  snapper
//
//  Created by ChenHao on 12/23/15.
//  Copyright © 2015 HarriesChen. All rights reserved.
//

struct SocketStringReader {

    let message: String
    var currentIndex: String.Index
    var hasNext: Bool {
        return currentIndex != message.endIndex
    }

    var currentCharacter: String {
        return String(message[currentIndex])
    }

    init(message: String) {
        self.message = message
        currentIndex = message.startIndex
    }

    @discardableResult
    mutating func advance(by: Int) -> String.UTF16View.Index {
        currentIndex = message.utf16.index(currentIndex, offsetBy: by)
        return currentIndex
    }

    mutating func read(readLength: Int) -> String {
        let maxDistance = message.distance(from: currentIndex, to: message.endIndex)
        let maxReadLength = min(maxDistance, readLength)
        let readString = message[currentIndex..<message.index(currentIndex, offsetBy: maxReadLength)]
        
        advance(by: maxReadLength)

        return String(readString)
    }

    mutating func readUntilStringOccurence(string: String) -> String {
        let substring = message.utf16[currentIndex..<message.utf16.endIndex]
        
        guard let foundIndex = substring.firstIndex(of: string.utf16.first!) else {
            currentIndex = message.utf16.endIndex
            
            return String(substring)!
        }
        
        advance(by: substring.distance(from: substring.startIndex, to: foundIndex) + 1)
        
        return String(substring[substring.startIndex..<foundIndex])!
    }

    mutating func readUntilEnd() -> String {
        return read(readLength: message.distance(from: currentIndex, to: message.endIndex))
    }
}
