// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import XCTest
@testable import XMLRPCServer

class XMLRPCRequestTests: XCTestCase {
    func testCompletelyInvalidMethodRequest() {
        let xmlString = "<root><foo>bar</foo><baz/></root>"
        let xmlDocument = try! XMLDocument(xmlString: xmlString)
        XCTAssertNil(XMLRPCRequest(from: xmlDocument))
    }

    func testMethodRequestWithoutParams() {
        let xmlString = "<methodCall><methodName>examples.getStateName</methodName></methodCall>"
        let xmlDocument = try! XMLDocument(xmlString: xmlString)
        let request = XMLRPCRequest(from: xmlDocument)!
        let params: [String]? = request.params()
        XCTAssertNil(params)
    }

    func testMethodRequestStructurallyInvalidParams() {
        let xmlString = "<methodCall><methodName>examples.getStateName</methodName><params><foo></foo></params></methodCall>"
        let xmlDocument = try! XMLDocument(xmlString: xmlString)
        let request = XMLRPCRequest(from: xmlDocument)!
        let params: [String]? = request.params()
        XCTAssertNil(params)
    }

    func testMethodRequestWithParams() {
        let xmlString = "<methodCall><methodName>examples.getStateName</methodName><params><param><value><i4>0</i4></value></param></params></methodCall>"
        let xmlDocument = try! XMLDocument(xmlString: xmlString)
        let request = XMLRPCRequest(from: xmlDocument)!
        let mismatchedParams: [String]? = request.params()
        XCTAssertNil(mismatchedParams)
        let validParams: [Int32]? = request.params()
        XCTAssertEqual(validParams, [0])
    }
}
