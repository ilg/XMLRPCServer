// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Ambassador
import Embassy
import XCTest
import XMLRPCClient
import XMLRPCCoder
@testable import XMLRPCServer

class XMLRPCWebAppTests: XCTestCase {
    private func assertIsFault(
        bytes: Data,
        expectedCode: Int32,
        expectedMessage: String,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let parsedXML = try XMLDocument(data: bytes)
        let rootElement = try XCTUnwrap(parsedXML.rootElement(), file: file, line: line)
        XCTAssert(rootElement.name == .methodResponse, file: file, line: line)
        let faultElement = try XCTUnwrap(
            rootElement
                .singleChild(named: .fault)?
                .singleChild(named: .value)?
                .singleChild(named: .struct)
                as? XMLElement,
            file: file,
            line: line
        )
        let fault = try XMLRPCCoder().decode(toType: MethodResult<Int>.Fault.self, from: faultElement)
        XCTAssertEqual(fault.faultCode, expectedCode, file: file, line: line)
        XCTAssertEqual(fault.faultString, expectedMessage, file: file, line: line)
    }

    private struct CoderAlwaysThrows: XMLRPCCoderProtocol {
        func encode(_: some Encodable) throws -> XMLElement { throw NSError() }
        func decode<D>(toType _: D.Type, from _: XMLElement) throws -> D where D: Decodable { throw NSError() }
    }

    func testWithBadEnviron() throws {
        let helper = WebAppMockingHelper()
        var webApp = XMLRPCWebApp()
        var logs: [String] = []
        webApp.logger = { logs.append($0) }
        webApp.app([:], startResponse: helper.startResponse, sendBody: helper.sendBody)

        XCTAssertEqual(helper.receivedStatus, "200 OK")
        XCTAssertEqual(helper.headersDict["Content-Type"], "application/xml")

        let bytes = helper.assertReceivedDataStructureAndGetBytes()
        try assertIsFault(bytes: bytes, expectedCode: 1, expectedMessage: "")

        XCTAssertEqual(logs, ["Unable to convert environ[\"swsgi.input\"] to SWSGIInput"])
    }

    func testWithBadData() throws {
        let helper = WebAppMockingHelper()

        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data("something".utf8))
            handler!(Data())
        }

        var webApp = XMLRPCWebApp()
        var logs: [String] = []
        webApp.logger = { logs.append($0) }
        webApp.app(["swsgi.input": input], startResponse: helper.startResponse, sendBody: helper.sendBody)

        XCTAssertEqual(helper.receivedStatus, "200 OK")
        XCTAssertEqual(helper.headersDict["Content-Type"], "application/xml")

        let bytes = helper.assertReceivedDataStructureAndGetBytes()
        try assertIsFault(bytes: bytes, expectedCode: 1, expectedMessage: "")

        XCTAssertEqual(logs, ["error in XMLReader.read: Error Domain=NSXMLParserErrorDomain Code=4 \"Line 1: Document is empty\n\" UserInfo={NSLocalizedDescription=Line 1: Document is empty\n}"])
    }

    func testWithMalformedRequest() throws {
        let helper = WebAppMockingHelper()

        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data("<root></root>".utf8))
            handler!(Data())
        }

        var webApp = XMLRPCWebApp()
        var logs: [String] = []
        webApp.logger = { logs.append($0) }
        webApp.app(["swsgi.input": input], startResponse: helper.startResponse, sendBody: helper.sendBody)

        XCTAssertEqual(helper.receivedStatus, "200 OK")
        XCTAssertEqual(helper.headersDict["Content-Type"], "application/xml")

        let bytes = helper.assertReceivedDataStructureAndGetBytes()
        try assertIsFault(bytes: bytes, expectedCode: 1, expectedMessage: "")

        XCTAssertEqual(logs, ["XMLReader.read handler failed to parse request from <?xml version=\"1.0\"?><root></root>"])
    }

    func testMethodNotFound() throws {
        let helper = WebAppMockingHelper()

        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data("<methodCall><methodName>foo</methodName></methodCall>".utf8))
            handler!(Data())
        }

        var webApp = XMLRPCWebApp()
        var logs: [String] = []
        webApp.logger = { logs.append($0) }
        webApp.app(["swsgi.input": input], startResponse: helper.startResponse, sendBody: helper.sendBody)

        XCTAssertEqual(helper.receivedStatus, "200 OK")
        XCTAssertEqual(helper.headersDict["Content-Type"], "application/xml")

        let bytes = helper.assertReceivedDataStructureAndGetBytes()
        try assertIsFault(bytes: bytes, expectedCode: 1, expectedMessage: "")

        XCTAssertEqual(logs, ["XMLReader.read handler failed to get method handler for foo"])
    }

    func testResponseEncodeFailure() {
        let helper = WebAppMockingHelper()

        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data("<methodCall><methodName>foo</methodName></methodCall>".utf8))
            handler!(Data())
        }

        var webApp = XMLRPCWebApp()
        webApp.coder = CoderAlwaysThrows()
        var logs: [String] = []
        webApp.logger = { logs.append($0) }
        webApp.foo = { (_: [Bool]) -> MethodResult<Int32> in .success(0) }
        webApp.app(["swsgi.input": input], startResponse: helper.startResponse, sendBody: helper.sendBody)

        XCTAssertEqual(logs, ["XMLReader.read handler failed to get response document from method handler"])
    }

    func testFault() {
        var webApp = XMLRPCWebApp()
        let faultApp = webApp.fault(code: 1, message: "")
        XCTAssert(faultApp is XMLResponse)

        webApp.coder = CoderAlwaysThrows()
        let internalServerError = webApp.fault(code: 1, message: "")
        XCTAssert(internalServerError is DataResponse)
    }

    func testMethodHandlerDynamicMemberLookupUnset() {
        let webApp = XMLRPCWebApp()
        let nonexistentHandler: XMLRPCWebApp.Handler<Int32, Int32>? = webApp.foo
        XCTAssertNil(nonexistentHandler)
    }

    func testMethodHandlerDynamicMemberLookupSetThenUnset() {
        var webApp = XMLRPCWebApp()
        let add: XMLRPCWebApp.Handler<Int32, Int32> = { (addends: [Int32]) -> MethodResult<Int32> in
            .success(addends.reduce(Int32(0)) { runningTotal, nextValue in
                runningTotal + nextValue
            })
        }
        webApp.add = add
        let roundTripedAdd: XMLRPCWebApp.Handler<Int32, Int32>? = webApp.add
        XCTAssertNotNil(roundTripedAdd)
        let result = roundTripedAdd?([2, 3] as [Int32])
        switch result {
        case let .success(value)?:
            XCTAssertEqual(value, 5)
        default:
            XCTFail()
        }
        webApp.add = nil as XMLRPCWebApp.Handler<Int32, Int32>?
        let nonexistentHandler: XMLRPCWebApp.Handler<Int32, Int32>? = webApp.add
        XCTAssertNil(nonexistentHandler)
    }

    func testMethodHandlerDynamicMemberLookupTypeMismatch() {
        var webApp = XMLRPCWebApp()
        let add: XMLRPCWebApp.Handler<Int32, Int32> = { (addends: [Int32]) -> MethodResult<Int32> in
            .success(addends.reduce(Int32(0)) { runningTotal, nextValue in
                runningTotal + nextValue
            })
        }
        webApp.add = add
        let notAdd: XMLRPCWebApp.Handler<String, Int32>? = webApp.add
        XCTAssertNil(notAdd)
        webApp.add = notAdd
        let nonexistentHandler: XMLRPCWebApp.Handler<String, Int32>? = webApp.add
        XCTAssertNil(nonexistentHandler)
    }

    func testLogger() throws {
        let helper = WebAppMockingHelper()
        var webApp = XMLRPCWebApp()
        var logs: [String] = []
        webApp.logger = { logs.append($0) }
        webApp.app([:], startResponse: helper.startResponse, sendBody: helper.sendBody)

        XCTAssertEqual(helper.receivedStatus, "200 OK")
        XCTAssertEqual(helper.headersDict["Content-Type"], "application/xml")

        let bytes = helper.assertReceivedDataStructureAndGetBytes()
        try assertIsFault(bytes: bytes, expectedCode: 1, expectedMessage: "")

        XCTAssertEqual(logs, ["Unable to convert environ[\"swsgi.input\"] to SWSGIInput"])
    }
}
