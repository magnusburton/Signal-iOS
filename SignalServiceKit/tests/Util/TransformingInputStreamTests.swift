//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest
@testable import SignalServiceKit

final class TransformingInputStreamTests: XCTestCase {
    func testRoundTrip() throws {

        let iv = Cryptography.generateRandomBytes(UInt(16))
        let encryptionKey = Cryptography.generateRandomBytes(UInt(32))
        let hmacKey = Cryptography.generateRandomBytes(UInt(32))

        let outputStream = TextBackedOutputStream()
        let transformingOutputStream = TransformingOutputStream(
            transforms: [
                ChunkedOutputStreamTransform(),
                try GzipCompressingStreamTransform(),
                try EncryptingStreamTransform(iv: iv, encryptionKey: encryptionKey, hmacKey: hmacKey)
            ],
            outputStream: outputStream
        )

        try transformingOutputStream.write(data: "w".data(using: .utf8)!)
        try transformingOutputStream.write(data: "xx".data(using: .utf8)!)
        try transformingOutputStream.write(data: "yyy".data(using: .utf8)!)

        try transformingOutputStream.close()

        let inputData = outputStream.accumulation
        let inputStream = TextBackedInputStream(data: inputData)

        let transformingIntputStream = TransformingInputStream(
            transforms: [
                try DecryptingStreamTransform(iv: iv, encryptionKey: encryptionKey, hmacKey: hmacKey),
                try GzipDecompressingStreamTransform(),
                ChunkedInputStreamTransform()
            ],
            inputStream: inputStream
        )

        var results = [Data]()
        while transformingIntputStream.hasBytesAvailable {
            results.append(try transformingIntputStream.read(maxLength: 64))
        }
        try transformingIntputStream.close()

        XCTAssertEqual(results.filter({$0.count > 0}).count, 3)
    }
}
