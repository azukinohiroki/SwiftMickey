# SwiftMickey
swift implementation of The MICKEY Stream Ciphers version 1

## Caution
this is NOT for version 2.0

## How To Use
copy Keystream.swift

```swift
let key = Data(hex: "0102030405060708090A")
let iv  = Data(hex: "12345678")
let ks = Keystream()
let stream = ks.stream(key: key, iv: iv, length: iv.count)
```

