// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation
import XMLRPCCoder

struct XMLRPCRequest {
    let methodName: String
    private let rootChildren: [XMLNode]

    func params<ParamType: Decodable>(coder: XMLRPCCoderProtocol = XMLRPCCoder()) -> [ParamType]? {
        guard
            rootChildren.count == 2,
            let paramsNode = rootChildren.last,
            paramsNode.name == .params,
            let paramNodes = paramsNode.children
        else {
            return nil
        }
        let params: [ParamType] = paramNodes.compactMap { xmlNode in
            guard
                xmlNode.name == .param,
                let valueNode = xmlNode.singleChild(named: .value),
                let xmlElement = valueNode.singleChild as? XMLElement
            else {
                return nil
            }
            return try? coder.decode(toType: ParamType.self, from: xmlElement)
        }
        guard params.count == paramNodes.count else { return nil }
        return params
    }

    init?(from xmlDocument: XMLDocument) {
        guard
            let root = xmlDocument.rootElement(),
            root.name == .methodCall,
            let rootChildren = root.children,
            rootChildren.count <= 2,
            let methodNameNode = rootChildren.first,
            methodNameNode.name == .methodName,
            let methodName = methodNameNode.stringValue
        else {
            return nil
        }
        self.methodName = methodName
        self.rootChildren = rootChildren
    }
}
