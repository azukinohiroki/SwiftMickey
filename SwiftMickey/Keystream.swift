// MIT License
//
// Copyright (c) 2020 azukinohiroki
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

class Keystream {
    private let R_MASK: [UInt32] = [0x1d5363d5, 0x415a0aac, 0x0000d2a8]
    private let COMP0: [UInt32] = [0x6aa97a30, 0x7942a809, 0x00003fea]
    private let COMP1: [UInt32] = [0xdd629e9a, 0xe3a21d63, 0x00003dd7]
    private let S_MASK0: [UInt32] = [0x9ffa7faf, 0xaf4a9381, 0x00005802]
    private let S_MASK1: [UInt32] = [0x4c8cb877, 0x4911b063, 0x0000c52b]

    private var encrypt = Encrypt()

    private func clock_r(_ encrypt: Encrypt, _ input_bit: UInt8, _ control_bit: UInt8) {
        var r0 = encrypt.r[0]
        var r1 = encrypt.r[1]
        var r2 = encrypt.r[2]
        let feedback_bit = UInt8((r2 >> 15) & 1) ^ input_bit
        let carry0 = (r0 >> 31) & 1
        let carry1 = (r1 >> 31) & 1

        if control_bit != 0 {
            r0 ^= (r0 << 1)
            r1 ^= ((r1 << 1) ^ carry0)
            r2 ^= ((r2 << 1) ^ carry1)
        } else {
            r0 = (r0 << 1)
            r1 = ((r1 << 1) ^ carry0)
            r2 = ((r2 << 1) ^ carry1)
        }

        if feedback_bit != 0 {
            r0 ^= self.R_MASK[0]
            r1 ^= self.R_MASK[1]
            r2 ^= self.R_MASK[2]
        }

        encrypt.r[0] = r0
        encrypt.r[1] = r1
        encrypt.r[2] = r2
    }

    private func clock_s(_ encrypt: Encrypt, _ input_bit: UInt8, _ control_bit: UInt8) {
        var s0 = encrypt.s[0]
        var s1 = encrypt.s[1]
        var s2 = encrypt.s[2]
        let feedback_bit = UInt8((s2 >> 15) & 1) ^ input_bit
        let carry0 = (s0 >> 31) & 1
        let carry1 = (s1 >> 31) & 1
        s0 = (s0 << 1) ^ ((s0 ^ self.COMP0[0]) & ((s0 >> 1) ^ (s1 << 31) ^ self.COMP1[0]) & 0xfffffffe)
        s1 = (s1 << 1) ^ ((s1 ^ self.COMP0[1]) & ((s1 >> 1) ^ (s2 << 31) ^ self.COMP1[1])) ^ carry0
        s2 = (s2 << 1) ^ ((s2 ^ self.COMP0[2]) & ((s2 >> 1) ^ self.COMP1[2]) & 0x7fff) ^ carry1

        if feedback_bit != 0 {
            if control_bit != 0 {
                s0 ^= self.S_MASK1[0]
                s1 ^= self.S_MASK1[1]
                s2 ^= self.S_MASK1[2]
            } else {
                s0 ^= self.S_MASK0[0]
                s1 ^= self.S_MASK0[1]
                s2 ^= self.S_MASK0[2]
            }
        }

        encrypt.s[0] = s0
        encrypt.s[1] = s1
        encrypt.s[2] = s2
    }

    private func clock_kg(_ encrypt: Encrypt, _ mixing: Int, _ input_bit: UInt8) -> UInt8 {
        let r0 = encrypt.r[0]
        let r1 = encrypt.r[1]
        let s0 = encrypt.s[0]
        let s1 = encrypt.s[1]
        let key_stream_bit = UInt8((r0 ^ s0) & 1)
        let control_bit_r = UInt8(((s0 >> 27) ^ (r1 >> 21)) & 1)
        let control_bit_s = UInt8(((s1 >> 21) ^ (r0 >> 26)) & 1)

        if mixing != 0 {
            self.clock_r(encrypt, UInt8(((s1 >> 8) & 1)) ^ input_bit, control_bit_r)
        } else {
            self.clock_r(encrypt, input_bit, control_bit_r)
        }

        self.clock_s(encrypt, input_bit, control_bit_s)

        return key_stream_bit
    }

    private func setup(_ encrypt: Encrypt, _ key: [UInt8], _ iv: [UInt8]) {
        let key_size = key.count
        let iv_size = iv.count

        for i in 0..<3 {
            encrypt.r[i] = 0
            encrypt.s[i] = 0
        }

        let ivArr = [UInt8](iv)
        for i in 0..<iv_size*8 {
            let iv_key_bit = (ivArr[i/8] >> (i % 8)) & UInt8(1)
            _ = self.clock_kg(encrypt, 1, iv_key_bit)
        }

        let keyArr = [UInt8](key)
        for i in 0..<key_size*8 {
            let iv_key_bit = (keyArr[i/8] >> (i % 8)) & UInt8(1)
            _ = self.clock_kg(encrypt, 1, iv_key_bit)
        }

        for _ in 0..<80 {
            _ = self.clock_kg(encrypt, 1, 0)
        }
    }

    func stream(key: Data, iv: Data, length: Int) -> String {
        var resource = ""
        encrypt = Encrypt()
        self.setup(encrypt, key.reversed(), iv.reversed())

        for _ in 0..<length {
            var t_keystream: UInt8 = 0

            for j in 0..<8 {
                t_keystream ^= self.clock_kg(encrypt, 0, 0) << Int(7 - j)
            }

            let key_result = t_keystream.data.hexEncodedString()
            resource = resource + key_result
        }

        return resource
    }
}

private class Encrypt {
    var r: [UInt32] = Array(repeating: UInt32(0), count: 3)
    var s: [UInt32] = Array(repeating: UInt32(0), count: 3)
}

private extension Data {
    func hexEncodedString() -> String {
        let format = "%02hhX"
        return map { String(format: format, $0) }.joined()
    }

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

private func intToData<T: FixedWidthInteger>(_ val: T) -> Data {
    var int = val.bigEndian
    return Data(bytes: &int, count: MemoryLayout<T>.size)
}

private extension UInt8 {
    var data: Data {
        intToData(self)
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
