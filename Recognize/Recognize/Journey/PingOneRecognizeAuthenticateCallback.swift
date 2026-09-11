//
//  PingOneRecognizeAuthenticateCallback.swift
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

/// A Journey callback that drives PingOne Recognize biometric **authentication**.
///
/// Returned by `RecognizeCallback` when the server sets `operationType` to `AUTHENTICATE`.
///
/// When the server also supplies a `clientState`, `authenticate()` first checks whether the
/// device is already enrolled: if not, it runs enrollment with that `clientState` instead
/// of authenticating (the enrollment-restore path) — matching Android's `authenticate()`.
///
/// **Usage:**
/// ```swift
/// if let callback = node.callbacks.first(where: { $0 is PingOneRecognizeAuthenticateCallback })
///         as? PingOneRecognizeAuthenticateCallback {
///     let result = await callback.authenticate()
/// }
/// ```
open class PingOneRecognizeAuthenticateCallback: AbstractRecognizeCallback, @unchecked Sendable {

    /// Configures the Keyless SDK and performs the authentication (or enrollment-restore)
    /// operation.
    ///
    /// - Parameter block: Configures the operation, e.g. `{ $0.retrieveSelfie = true }`.
    ///   `retrieveSelfie` defaults to `false` and is always an explicit, app-level decision —
    ///   it is never read from the server's `mobileSDKOptions`. Applies to the enrollment-restore
    ///   path too, since it runs under this same call.
    /// - Returns: `.success(RecognizeSuccess)` on completion, or `.failure(error)` if any step fails.
    ///   On failure the `clientError` input field is automatically populated.
    public func authenticate(
        _ block: @Sendable (RecognizeAuthenticateConfig) -> Void = { _ in }
    ) async -> Result<RecognizeSuccess, Error> {
        let config = RecognizeAuthenticateConfig()
        block(config)
        do {
            try requireRecognizedOperationType()
            try await configure()
            try Task.checkCancellation()
            let result: RecognizeSuccess
            if !clientState.isEmpty {
                result = try await enrollWithClientStateIfNeeded(
                    clientState, retrieveSelfie: config.retrieveSelfie, options: mobileSDKOptions
                )
            } else {
                result = try await performAuthenticate(retrieveSelfie: config.retrieveSelfie, options: mobileSDKOptions)
            }
            return .success(result)
        } catch {
            report(error)
            return .failure(error)
        }
    }

    // MARK: - Enrollment-restore path

    /// The outcome of `validateUserDeviceActive()`.
    ///
    /// Returns a tri-state enum so tests can inject any outcome without constructing
    /// the internal-init `KeylessSDKError` type:
    /// - `.active` — device is enrolled, proceed with authentication.
    /// - `.notEnrolled` — device is not enrolled, proceed with enrollment.
    /// - `.otherError(message:code:debuggingInfo:)` — unexpected error, propagate to caller.
    public enum ValidationResult: Sendable {
        case active
        case notEnrolled
        case otherError(message: String, code: Int, debuggingInfo: [String: String] = [:])
    }

    /// Validates whether the current device is active (enrolled) in the Keyless SDK.
    ///
    /// Extracted as `open` so test subclasses can override it.
    open func validateUserDeviceActive() async -> ValidationResult {
        await withCheckedContinuation { continuation in
            Keyless.validateUserDeviceActive { error in
                guard let error else {
                    continuation.resume(returning: .active)
                    return
                }
                if case .integrationError(let ie) = error.kind, ie == .userNotEnrolled {
                    continuation.resume(returning: .notEnrolled)
                } else {
                    continuation.resume(returning: .otherError(
                        message: error.message, code: error.code, debuggingInfo: error.debuggingInfo
                    ))
                }
            }
        }
    }

    /// Handles the authenticate-with-clientState path: checks whether the user is already enrolled.
    ///
    /// - If `validateUserDeviceActive` returns `.active`, the user is already enrolled — delegates
    ///   to `performAuthenticate`.
    /// - If it returns `.notEnrolled`, runs enrollment with the server-supplied client state.
    /// - Any other error is propagated as a `RecognizeError`.
    open func enrollWithClientStateIfNeeded(
        _ clientState: String,
        retrieveSelfie: Bool = false,
        options: RecognizeMobileSDKOptions
    ) async throws -> RecognizeSuccess {
        let validation = await validateUserDeviceActive()

        switch validation {
        case .active:
            try Task.checkCancellation()
            return try await performAuthenticate(retrieveSelfie: retrieveSelfie, options: options)
        case .otherError(let message, let code, let debuggingInfo):
            throw RecognizeError(message, code: code, debuggingInfo: debuggingInfo)
        case .notEnrolled:
            try Task.checkCancellation()
            return try await performEnroll(clientStateOverride: clientState, retrieveSelfie: retrieveSelfie, options: options)
        }
    }
}
#endif
