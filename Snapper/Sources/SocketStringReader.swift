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
    
    mutating func advanceIndexBy(n: Int) {
        currentIndex = currentIndex.advancedBy(n)
    }
    
    mutating func read(readLength: Int) -> String {
        let readString = message[currentIndex..<currentIndex.advancedBy(readLength)]
        advanceIndexBy(readLength)
        
        return readString
    }
    
    mutating func readUntilStringOccurence(string: String) -> String {
        let substring = message[currentIndex..<message.endIndex]
        guard let foundRange = substring.rangeOfString(string) else {
            currentIndex = message.endIndex
            
            return substring
        }
        
        advanceIndexBy(message.startIndex.distanceTo(foundRange.startIndex) + 1)
        
        return substring.substringToIndex(foundRange.startIndex)
    }
    
    mutating func readUntilEnd() -> String {
        return read(currentIndex.distanceTo(message.endIndex))
    }
}