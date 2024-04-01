// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Embassy
import XCTest

class WebAppMockingHelper {
    var receivedStatus: String?
    var receivedHeaders: [(String, String)]?
    var receivedData: [Data] = []

    func startResponse(status: String, headers: [(String, String)]) {
        receivedStatus = status
        receivedHeaders = headers
    }

    func sendBody(data: Data) {
        receivedData.append(data)
    }

    var headersDict: MultiDictionary<String, String, LowercaseKeyTransform> {
        MultiDictionary<String, String, LowercaseKeyTransform>(items: receivedHeaders ?? [])
    }

    func assertReceivedDataStructureAndGetBytes(
        file: StaticString = #file,
        line: UInt = #line
    ) -> Data {
        XCTAssertEqual(receivedData.count, 2, file: file, line: line)
        XCTAssertEqual(receivedData.last?.count, 0, file: file, line: line)
        return receivedData.first ?? Data()
    }
}
