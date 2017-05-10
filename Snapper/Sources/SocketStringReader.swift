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

    mutating func advanceIndexBy(_ length: Int) {
        currentIndex = message.index(currentIndex, offsetBy: length)
    }

    mutating func read(readLength: Int) -> String {
        let maxDistance = message.distance(from: currentIndex, to: message.endIndex)
        let maxReadLength = min(maxDistance, readLength)
        let readString = message[currentIndex..<message.index(currentIndex, offsetBy: maxReadLength)]
        advanceIndexBy(maxReadLength)

        return readString
    }

    mutating func readUntilStringOccurence(string: String) -> String {
        let substring = message[currentIndex..<message.endIndex]
        guard let foundRange = substring.range(of: string) else {
            currentIndex = message.endIndex

            return substring
        }

        let distance = message.distance(from: message.startIndex, to: foundRange.lowerBound) + 1
        advanceIndexBy(distance)

        return substring.substring(to: foundRange.lowerBound)
    }

    mutating func readUntilEnd() -> String {
        return read(readLength: message.distance(from: currentIndex, to: message.endIndex))
    }
}
