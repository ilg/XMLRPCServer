// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation
import XMLRPCCoder

struct XMLRPCMethodHandler<ParamType: Decodable, SuccessType: Encodable> {
    let handler: XMLRPCWebApp.Handler<ParamType, SuccessType>
}

protocol MethodHandlerProtocol {
    func responseDocument(request: XMLRPCRequest, coder: XMLRPCCoderProtocol) -> XMLDocument?
}

extension XMLRPCMethodHandler: MethodHandlerProtocol {
    func responseDocument(request: XMLRPCRequest, coder: XMLRPCCoderProtocol) -> XMLDocument? {
        let params: [ParamType] = request.params(coder: coder) ?? []
        return handler(params).responseDocument(coder: coder)
    }
}
