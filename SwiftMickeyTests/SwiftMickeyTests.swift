//
//  SwiftMickeyTests.swift
//  SwiftMickeyTests
//
//  Created by Hiroki Taoka on 2020/07/22.
//  Copyright © 2020 Hiroki Taoka. All rights reserved.
//

import XCTest
@testable import SwiftMickey

class SwiftMickeyTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testKeystream() throws {
        let key = Data(hex: "0102030405060708090A")
        let iv  = Data(hex: "12345678")
        let ks = Keystream()
        let stream = ks.stream(key: key, iv: iv, length: iv.count)
        XCTAssertEqual(stream, "2F0F8674")
    }
}

private extension Data {
    init(hex: String) {
        let scalars = hex.unicodeScalars
        var bytes = Array<UInt8>(repeating: 0, count: (scalars.count + 1) >> 1)
        for (index, scalar) in scalars.enumerated() {
            var nibble = scalar.hexNibble
            if index & 1 == 0 {
                nibble <<= 4
            }
            bytes[index >> 1] |= nibble
        }
        self = Data(bytes)
    }
}

private extension UnicodeScalar {
    var hexNibble: UInt8 {
        let value = self.value
        if 48 <= value && value <= 57 {
            return UInt8(value - 48)
        }
        else if 65 <= value && value <= 70 {
            return UInt8(value - 55)
        }
        else if 97 <= value && value <= 102 {
            return UInt8(value - 87)
        }
        fatalError("\(self) not a legal hex nibble")
    }
}
