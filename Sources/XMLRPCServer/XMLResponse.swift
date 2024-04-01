// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Ambassador
import Foundation

/// A response app for responding XML data
struct XMLResponse: WebApp {
    /// Underlying data response
    let dataResponse: DataResponse

    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/xml",
        headers: [(String, String)] = [],
        handler: @escaping (_ environ: [String: Any], _ sendXML: @escaping (XMLDocument) -> Void) -> Void
    ) {
        dataResponse = DataResponse(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            headers: headers
        ) { environ, sendData in
            handler(environ) { xmlDocument in
                sendData(xmlDocument.xmlData)
            }
        }
    }

    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/xml",
        headers: [(String, String)] = [],
        handler: @escaping ((_ environ: [String: Any]) -> XMLDocument)
    ) {
        self.init(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            headers: headers,
            handler: { environ, sendXML in
                let xmlDocument = handler(environ)
                sendXML(xmlDocument)
            }
        )
    }

    public func app(
        _ environ: [String: Any],
        startResponse: @escaping ((String, [(String, String)]) -> Void),
        sendBody: @escaping ((Data) -> Void)
    ) {
        dataResponse.app(environ, startResponse: startResponse, sendBody: sendBody)
    }
}
