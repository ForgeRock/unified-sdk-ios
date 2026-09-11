//
//  RecognizeConfig.swift
//  PingRecognize
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

#if canImport(KeylessSDK)

/// Caller-supplied configuration for `PingOneRecognizeEnrollCallback.enroll(_:)`.
///
/// ```swift
/// let result = await callback.enroll { config in
///     config.retrieveSelfie = true
/// }
/// ```
public class RecognizeEnrollConfig: @unchecked Sendable {
    /// When `true`, the enrollment frame (selfie) is captured and returned in
    /// `RecognizeSuccess.selfie`. Defaults to `false`. Unlike the rest of the SDK
    /// configuration, this is never read from the server's `mobileSDKOptions` —
    /// it is always an explicit, app-level decision, matching Android.
    public var retrieveSelfie: Bool = false

    public init() {}
}

/// Caller-supplied configuration for `PingOneRecognizeAuthenticateCallback.authenticate(_:)`.
///
/// ```swift
/// let result = await callback.authenticate { config in
///     config.retrieveSelfie = true
/// }
/// ```
public class RecognizeAuthenticateConfig: @unchecked Sendable {
    /// When `true`, the authentication frame (selfie) is captured and returned in
    /// `RecognizeSuccess.selfie`. Defaults to `false`. Also applies to the
    /// enrollment-restore path (when the server supplies a `clientState` for an
    /// unenrolled device), since it runs under the same `authenticate()` call.
    public var retrieveSelfie: Bool = false

    public init() {}
}
#endif
