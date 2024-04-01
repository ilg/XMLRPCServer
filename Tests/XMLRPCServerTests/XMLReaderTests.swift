// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import XCTest
@testable import XMLRPCServer

class XMLReaderTests: XCTestCase {
    func testXMLReader() {
        let xmlString = "<root><foo>bar</foo><baz/></root>"

        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data(xmlString.utf8))
            handler!(Data())
        }
        let expectation = XCTestExpectation(description: "async call finished")
        XMLReader.read(input) { xmlDocument in
            XCTAssertEqual(xmlDocument.rootElement(), try! XMLDocument(xmlString: xmlString).rootElement())
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testXMLReaderAsync() async throws {
        let xmlString = "<root><foo>bar</foo><baz/></root>"

        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data(xmlString.utf8))
            handler!(Data())
        }
        let xmlDocument = try await XMLReader.read(input)
        XCTAssertEqual(xmlDocument.rootElement(), try! XMLDocument(xmlString: xmlString).rootElement())
    }

    func testXMLReaderWithBadData() {
        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data("something".utf8))
            handler!(Data())
        }
        let expectation = XCTestExpectation(description: "async call finished")
        XMLReader.read(
            input,
            errorHandler: { error in
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, XMLParser.errorDomain)
                XCTAssertEqual(nsError.code, XMLParser.ErrorCode.emptyDocumentError.rawValue)
                expectation.fulfill()
            },
            handler: { _ in
                XCTFail()
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 1)
    }

    func testXMLReaderWithBadDataAsync() async {
        let input = { (handler: ((Data) -> Void)?) in
            handler!(Data("something".utf8))
            handler!(Data())
        }
        do {
            _ = try await XMLReader.read(input)
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, XMLParser.errorDomain)
            XCTAssertEqual(nsError.code, XMLParser.ErrorCode.emptyDocumentError.rawValue)
        }
    }
}
