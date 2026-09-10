//
//  RecognizeSuccess.swift
//  PingRecognize
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

#if canImport(KeylessSDK)
import CoreGraphics

/// The result of a successful PingOne Recognize biometric operation.
///
/// Returned by `PingOneRecognizeEnrollCallback.enroll()` and
/// `PingOneRecognizeAuthenticateCallback.authenticate()` on success.
public struct RecognizeSuccess: @unchecked Sendable {

    /// The signed JWT produced by the Keyless SDK, if JWT signing was configured.
    public let signedJwt: String?

    /// The client state blob produced by the Keyless SDK, if client-state generation was enabled.
    public let clientState: String?

    /// The Recognize user ID. Assigned during enrollment (from the enrollment result); on
    /// authentication it is read from the Keyless SDK
    public let recognizeId: String?

    /// The captured selfie frame, present only when `retrieveSelfie` was set to `true` via the
    /// config closure passed to `enroll()` / `authenticate()`. Never written to an input field —
    /// it reaches only the caller, never Journey or the callback payload.
    ///
    /// - Note: `CGImage` is not `Sendable`; `@unchecked Sendable` is used here because the
    ///   image is immutable once assigned and is only passed between tasks owned by the caller.
    public let selfie: CGImage?

    public init(signedJwt: String?, clientState: String?, recognizeId: String?, selfie: CGImage?) {
        self.signedJwt = signedJwt
        self.clientState = clientState
        self.recognizeId = recognizeId
        self.selfie = selfie
    }
}
#endif
