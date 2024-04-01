// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import XCTest
@testable import XMLRPCServer

import Ambassador
import Embassy

class XMLResponseTests: XCTestCase {
    func testAmbassadorXMLResponse() {
        let document = try! XMLDocument(xmlString: "<root><foo>bar</foo><baz/></root>")
        let xmlResponse = XMLResponse { _ -> XMLDocument in
            document
        }

        let helper = WebAppMockingHelper()

        xmlResponse.app([:], startResponse: helper.startResponse, sendBody: helper.sendBody)

        XCTAssertEqual(helper.receivedStatus, "200 OK")
        XCTAssertEqual(helper.headersDict["Content-Type"], "application/xml")

        let bytes = helper.assertReceivedDataStructureAndGetBytes()
        let parsedXML = try! XMLDocument(data: bytes)
        XCTAssertEqual(parsedXML, document)
    }
}
