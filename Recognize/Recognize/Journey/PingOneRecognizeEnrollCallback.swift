//
//  PingOneRecognizeEnrollCallback.swift
//  PingRecognize
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

#if canImport(KeylessSDK)
import Foundation
@preconcurrency import KeylessSDK
import PingJourneyPlugin

/// A Journey callback that drives PingOne Recognize biometric **enrollment**.
///
/// Returned by `RecognizeCallback` when the server sets `operationType` to `ENROLL`.
///
/// **Usage:**
/// ```swift
/// if let callback = node.callbacks.first(where: { $0 is PingOneRecognizeEnrollCallback })
///         as? PingOneRecognizeEnrollCallback {
///     let result = await callback.enroll()
/// }
/// ```
open class PingOneRecognizeEnrollCallback: AbstractRecognizeCallback, @unchecked Sendable {

    /// Configures the Keyless SDK and performs the enrollment operation.
    ///
    /// - Parameter block: Configures the operation, e.g. `{ $0.retrieveSelfie = true }`.
    ///   `retrieveSelfie` defaults to `false` and is always an explicit, app-level decision —
    ///   it is never read from the server's `mobileSDKOptions`.
    /// - Returns: `.success(RecognizeSuccess)` on completion, or `.failure(error)` if any step fails.
    ///   On failure the `clientError` input field is automatically populated.
    public func enroll(_ block: @Sendable (RecognizeEnrollConfig) -> Void = { _ in }) async -> Result<RecognizeSuccess, Error> {
        let config = RecognizeEnrollConfig()
        block(config)
        do {
            try requireRecognizedOperationType()
            try await configure()
            try Task.checkCancellation()
            let result = try await performEnroll(retrieveSelfie: config.retrieveSelfie, options: mobileSDKOptions)
            return .success(result)
        } catch {
            report(error)
            return .failure(error)
        }
    }
}
#endif
