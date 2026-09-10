//
//  RecognizeCallback.swift
//  PingRecognize
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

#if canImport(KeylessSDK)
import Foundation
import PingJourneyPlugin

/// Factory callback registered for the `"PingOneRecognizeCallback"` server type.
///
/// The server emits a single callback type for both enrollment and authentication.
/// `RecognizeCallback` reads the `operationType` output field during `initialize(with:)`
/// and returns the appropriate concrete instance, matching the server's stated intent:
/// - `ENROLL` → `PingOneRecognizeEnrollCallback`
/// - `AUTHENTICATE` → `PingOneRecognizeAuthenticateCallback` (handles the enrollment-restore
///   path internally when the server also supplies a `clientState`)
///
/// This class is not intended to be used directly — cast the result of
/// `node.callbacks` to `PingOneRecognizeEnrollCallback` or `PingOneRecognizeAuthenticateCallback`.
class RecognizeCallback: AbstractRecognizeCallback, @unchecked Sendable {

    override func initialize(with json: [String: Any]) async -> any Callback {
        // Parse shared output fields into self first.
        _ = await super.initialize(with: json)

        // An unrecognised `operationType` can't select a concrete callback here —
        // `initialize(with:)` isn't `throws` (a constraint shared by every Journey callback) —
        // so it falls back to `PingOneRecognizeEnrollCallback`; its `enroll()` fails closed
        // immediately via `requireRecognizedOperationType()` instead of running an enrollment
        // the server never asked for.
        let callback: AbstractRecognizeCallback
        switch operationType {
        case .enroll, nil:
            callback = PingOneRecognizeEnrollCallback()
        case .authenticate:
            callback = PingOneRecognizeAuthenticateCallback()
        }
        _ = await callback.initialize(with: json)
        return callback
    }
}
#endif
