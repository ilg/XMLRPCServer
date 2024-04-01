// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Ambassador
import Embassy
import Foundation

enum XMLReader {
    /// Read all data into bytes array and parse it as XML
    ///  - Parameter input: the SWSGI input to read from
    ///  - Parameter errorHandler: the handler to be called parsing XML failed
    ///  - Parameter handler: the handler to be called when finish reading all data and parsed as XML
    public static func read(
        _ input: SWSGIInput,
        errorHandler: ((Error) -> Void)? = nil,
        handler: @escaping ((XMLDocument) -> Void)
    ) {
        // DataReader invokes the block passed to read twice.  This bool latch prevents the second firing.
        // https://github.com/envoy/Ambassador/issues/18#issuecomment-318327926
        var readBlockHasFired = false
        DataReader.read(input) { data in
            guard !readBlockHasFired else { return }
            readBlockHasFired = true
            do {
                let xmlDocument = try XMLDocument(data: data)
                handler(xmlDocument)
            } catch {
                errorHandler?(error)
            }
        }
    }

    /// Read all data into bytes array and parse it as XML
    /// - Parameter input: the SWSGI input to read from
    /// - Returns: The resulting XML document
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public static func read(_ input: SWSGIInput) async throws -> XMLDocument {
        try await withCheckedThrowingContinuation { continuation in
            read(input) { error in
                continuation.resume(throwing: error)
            } handler: { document in
                continuation.resume(returning: document)
            }
        }
    }
}
