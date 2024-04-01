// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Ambassador
import Embassy
import Foundation
import XMLRPCCoder

@dynamicMemberLookup public struct XMLRPCWebApp: WebApp {
    public init() {}

    public var logger: ((String) -> Void)?
    public var coder: XMLRPCCoderProtocol = XMLRPCCoder()

    private var methodHandlers: [String: MethodHandlerProtocol] = [:]

    public typealias Handler<ParamType: Decodable, SuccessType: Encodable> = ([ParamType]) -> MethodResult<SuccessType>

    // swiftformat:disable:next opaqueGenericParameters
    public mutating func register<ParamType: Decodable, SuccessType: Encodable>(methodName: String, handler: @escaping Handler<ParamType, SuccessType>) {
        methodHandlers[methodName] = XMLRPCMethodHandler(handler: handler)
    }

    func fault(code: Int32, message: String, coder: XMLRPCCoderProtocol? = nil) -> WebApp {
        let coder = coder ?? self.coder
        guard let responseDocument = MethodResult<String>.fault(code: code, message: message).responseDocument(coder: coder) else {
            return DataResponse(statusCode: 500, statusMessage: "inernal server error")
        }
        return XMLResponse { _ in responseDocument }
    }

    private func app(environ: [String: Any], handler: @escaping (WebApp) -> Void) {
        guard let input = environ["swsgi.input"] as? SWSGIInput else {
            logger?("Unable to convert environ[\"swsgi.input\"] to SWSGIInput")
            handler(fault(code: 1, message: ""))
            return
        }
        XMLReader.read(
            input,
            errorHandler: { error in
                self.logger?("error in XMLReader.read: \(error)")
                handler(self.fault(code: 1, message: ""))
            },
            handler: { xmlDocument in
                guard let request = XMLRPCRequest(from: xmlDocument) else {
                    self.logger?("XMLReader.read handler failed to parse request from \(xmlDocument)")
                    handler(self.fault(code: 1, message: ""))
                    return
                }
                guard let methodHandler = self.methodHandlers[request.methodName] else {
                    self.logger?("XMLReader.read handler failed to get method handler for \(request.methodName)")
                    handler(self.fault(code: 1, message: ""))
                    return
                }
                guard let responseDocument = methodHandler.responseDocument(request: request, coder: self.coder) else {
                    self.logger?("XMLReader.read handler failed to get response document from method handler")
                    handler(self.fault(code: 1, message: ""))
                    return
                }
                handler(XMLResponse { _ in responseDocument })
            }
        )
    }

    public func app(_ environ: [String: Any], startResponse: @escaping ((String, [(String, String)]) -> Void), sendBody: @escaping ((Data) -> Void)) {
        app(environ: environ) { webApp in
            webApp.app(environ, startResponse: startResponse, sendBody: sendBody)
        }
    }
}

public extension XMLRPCWebApp {
    // For @dynamicMemberLookup to facilitate nicer-looking method definitions.
    subscript<ParamType: Decodable, SuccessType: Encodable>(dynamicMember methodName: String) -> Handler<ParamType, SuccessType>? {
        get {
            let handlerInGeneral = methodHandlers[methodName]
            guard let handler = handlerInGeneral as? XMLRPCMethodHandler<ParamType, SuccessType> else {
                return nil
            }
            return handler.handler
        }
        set(newValue) {
            guard let newValue else {
                methodHandlers[methodName] = nil
                return
            }
            register(methodName: methodName, handler: newValue)
        }
    }
}
