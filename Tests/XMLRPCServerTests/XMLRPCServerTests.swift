// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Ambassador
import Embassy
import ResultAssertions
import XCTest
import XMLRPCClient
import XMLRPCServer

private let timeout: TimeInterval = 1.5

class XMLRPCServerTests: XCTestCase {
    let port = 8080
    var router: Router!
    var eventLoop: SelectorEventLoop!
    var server: HTTPServer!

    var eventLoopThreadCondition: NSCondition!
    var eventLoopThread: Thread!

    let serverProxy = ServerProxy(session: URLSession.shared, url: URL(string: "http://localhost:8080/interface/xmlrpc")!)

    var lastChallenge: String = ""

    struct GetChallengeResponse: Codable {
        let auth_scheme: String
        let challenge: String
        let expire_time: Int32
        let server_time: Int32
        var isExpired: Bool {
            let expires = Date(timeIntervalSinceNow: TimeInterval(expire_time - server_time))
            return expires < Date()
        }

        func response(passwordMD5: String) -> String {
            "\(challenge)\(passwordMD5)"
        }
    }

    override func setUp() {
        super.setUp()

        var xmlrpcApp = XMLRPCWebApp()
        xmlrpcApp.add = { (addends: [Int32]) -> MethodResult<Int32> in
            .success(addends.reduce(Int32(0)) { runningTotal, nextValue in
                runningTotal + nextValue
            })
        }
        xmlrpcApp.div = { (numbers: [Int32]) -> MethodResult<Int32> in
            guard
                numbers.count == 2,
                let dividend = numbers.first,
                let divisor = numbers.last
            else { return .fault(code: 1, message: "") }
            return .success(dividend / divisor)
        }
        xmlrpcApp.pow = { (numbers: [Int32]) -> MethodResult<Int32> in
            guard
                numbers.count == 2,
                let base = numbers.first,
                let exponent = numbers.last
            else { return .fault(code: 1, message: "") }
            return .success(Int32(pow(Double(base), Double(exponent))))
        }
        xmlrpcApp.pi = { (_: [Bool]) -> MethodResult<Double> in
            .success(.pi)
        }
        var counter: Int32 = 0
        xmlrpcApp.counter = { (_: [Bool]) -> MethodResult<Int32> in
            counter += 1
            return .success(counter)
        }
        xmlrpcApp.getchallenge = { (_: [Bool]) -> MethodResult<GetChallengeResponse> in
            self.lastChallenge = UUID().uuidString.lowercased()
            print("lastChallenge set to \(self.lastChallenge)")
            print(Thread.callStackSymbols.joined(separator: "\n"))
            print("---------------------")
            let now = Int32(Date().timeIntervalSince1970)
            return .success(GetChallengeResponse(
                auth_scheme: "c0",
                challenge: self.lastChallenge,
                expire_time: now + 60,
                server_time: now
            ))
        }

        eventLoop = try! SelectorEventLoop(selector: try! KqueueSelector())
        router = Router()
        server = DefaultHTTPServer(eventLoop: eventLoop, port: port, app: router.app)
        router["/interface/xmlrpc"] = xmlrpcApp

        // Start HTTP server to listen on the port
        try! server.start()

        eventLoopThreadCondition = NSCondition()
        eventLoopThread = Thread(target: self, selector: #selector(runEventLoop), object: nil)
        eventLoopThread.start()
    }

    override func tearDown() {
        server.stopAndWait()
        eventLoopThreadCondition.lock()
        eventLoop.stop()
        while eventLoop.running {
            if !eventLoopThreadCondition.wait(until: Date().addingTimeInterval(10)) {
                fatalError("Join eventLoopThread timeout")
            }
        }
        super.tearDown()
    }

    @objc private func runEventLoop() {
        eventLoop.runForever()
        eventLoopThreadCondition.lock()
        eventLoopThreadCondition.signal()
        eventLoopThreadCondition.unlock()
    }

    private func assert(
        methodName: String,
        params: [some Encodable],
        expectedResult: some Decodable & Equatable,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        await serverProxy.execute(methodName: methodName, params: params)
            .assertHasValue(expectedResult, file: file, line: line)
    }

    func testValidMethods() async {
        await assert(methodName: "pow", params: [2, 3] as [Int32], expectedResult: Int32(8))
        await assert(methodName: "add", params: [2, 3] as [Int32], expectedResult: Int32(5))
        await assert(methodName: "add", params: [] as [Int32], expectedResult: Int32(0))
        await assert(methodName: "add", params: [2, 3, 4, 5] as [Int32], expectedResult: Int32(14))
        await assert(methodName: "div", params: [5, 2] as [Int32], expectedResult: Int32(2))
    }

    func testInvalidMethod() async {
        await (serverProxy.foo() as ServerProxy.Result<Int32>)
            .assertFault(expectedCode: 1)
    }

    func testMissingParameters() async {
        await (serverProxy.pow() as ServerProxy.Result<Int32>)
            .assertFault(expectedCode: 1)
    }

    func testBadParameters() async {
        await (serverProxy.pow(["A", "B"]) as ServerProxy.Result<Int32>)
            .assertFault(expectedCode: 1)
    }

    func testBadPathOnServer() async {
        guard let url = URL(string: "http://localhost:8080/foo") else { fatalError() }
        let serverProxy = ServerProxy(session: URLSession.shared, url: url)
        await (serverProxy.foo() as ServerProxy.Result<Int32>)
            .assertHTTPError(expectedCode: 404)
    }

    func testMethodWithNoParameters() async {
        await serverProxy.pi()
            .assertHasValue(Double.pi)
    }

    func testMethodHandlerCallCount() async {
        await serverProxy.counter()
            .assertHasValue(Int32(1))
        await serverProxy.counter()
            .assertHasValue(Int32(2))
    }

    func testGetChallenge() async throws {
        let response: GetChallengeResponse = try await serverProxy.getchallenge().get()
        XCTAssertEqual(response.challenge, lastChallenge)
    }
}
