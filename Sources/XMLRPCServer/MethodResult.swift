// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation
import XMLRPCCoder

public enum MethodResult<SuccessType: Encodable> {
    case success(SuccessType)
    case fault(code: Int32, message: String)

    struct Fault: Codable {
        let faultCode: Int32
        let faultString: String
    }

    func responseDocument(coder: XMLRPCCoderProtocol) -> XMLDocument? {
        switch self {
        case let .success(resultValue):
            guard let response = try? coder.encode(resultValue) else { return nil }
            return XMLDocument(
                rootElement: XMLElement(name: .methodResponse, children: [
                    XMLElement(name: .params, children: [
                        XMLElement(name: .param, children: [
                            XMLElement(name: .value, children: [response]),
                        ]),
                    ]),
                ]))
        case let .fault(code, message):
            guard let fault = try? coder.encode(Fault(faultCode: code, faultString: message)) else { return nil }
            return XMLDocument(
                rootElement: XMLElement(name: .methodResponse, children: [
                    XMLElement(name: .fault, children: [
                        XMLElement(name: .value, children: [fault]),
                    ]),
                ]))
        }
    }
}
