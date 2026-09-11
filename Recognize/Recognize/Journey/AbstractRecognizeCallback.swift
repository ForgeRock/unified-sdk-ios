//
//  AbstractRecognizeCallback.swift
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
import PingOrchestrate
import PingJourneyPlugin


// MARK: - RecognizeOperationType

/// The operation type conveyed by the server in the `operationType` output field.
public enum RecognizeOperationType: String, Sendable {
    case enroll = "ENROLL"
    case authenticate = "AUTHENTICATE"
}

// MARK: - RecognizeMobileSDKOptions

/// Typed wrapper around the `mobileSDKOptions` dictionary received from the server.
///
/// The server delivers all values as strings, including booleans (`"true"`/`"false"`) and
/// integers (`"2"`, `"5"`). Computed properties convert these to native Swift types.
public struct RecognizeMobileSDKOptions: Sendable {

    let raw: [String: String]

    // MARK: Common options

    /// The liveness detection configuration level (e.g. `"LEVEL_1"`).
    public var livenessConfiguration: String { raw[JourneyConstants.livenessConfiguration] ?? "" }

    /// Whether the SDK adapts its behaviour to the surrounding environment.
    public var livenessEnvironmentAware: Bool? { raw[JourneyConstants.livenessEnvironmentAware].flatMap(Bool.init) }

    /// The server-assigned operation info ID.
    public var operationInfoId: String { raw[JourneyConstants.operationInfoId] ?? "" }

    /// The server-assigned operation info payload.
    public var operationInfoPayload: String { raw[JourneyConstants.operationInfoPayload] ?? "" }

    /// The external user ID linked to this operation.
    public var operationInfoExternalUserId: String { raw[JourneyConstants.operationInfoExternalUserId] ?? "" }

    /// Delay in seconds before the camera activates.
    public var cameraDelaySeconds: Int? { raw[JourneyConstants.cameraDelaySeconds].flatMap(Int.init) }

    /// Whether to show a success feedback overlay after the operation completes.
    public var showSuccessFeedback: Bool? { raw[JourneyConstants.showSuccessFeedback].flatMap(Bool.init) }

    // MARK: Enrollment-only options

    /// Whether to show a failure feedback overlay when enrollment fails.
    public var showFailureFeedback: Bool? { raw[JourneyConstants.showFailureFeedback].flatMap(Bool.init) }

    /// Whether to display the instructions screen before the camera activates.
    public var showInstructionsScreen: Bool? { raw[JourneyConstants.showInstructionsScreen].flatMap(Bool.init) }

    /// The UI presentation style for enrollment (e.g. `"OVERLAY"`).
    public var presentation: String { raw[JourneyConstants.presentation] ?? "" }

    /// The number of enrollment circuits the SDK runs to capture biometrics.
    public var numberOfEnrollmentCircuits: Int? { raw[JourneyConstants.numberOfEnrollmentCircuits].flatMap(Int.init) }

    // MARK: Authentication-only options

    /// The UI presentation style for authentication (e.g. `"CAMERA_PREVIEW"`).
    public var presentationStyle: String { raw[JourneyConstants.presentationStyle] ?? "" }

}

// MARK: - AbstractRecognizeCallback

/// Abstract base class for PingOne Recognize callbacks in PingOne Journey workflows.
///
/// Provides shared output properties, input helpers, SDK configuration, and
/// field-parsing logic. Concrete subclasses implement the biometric operation:
/// - `PingOneRecognizeEnrollCallback` — enrollment
/// - `PingOneRecognizeAuthenticateCallback` — authentication, and enrollment-restore
///   when the server supplies a `clientState` for an unenrolled device
open class AbstractRecognizeCallback: AbstractCallback, ContinueNodeAware, @unchecked Sendable {

    /// Reference to the continue node for accessing other callbacks.
    public weak var continueNode: ContinueNode?

    // MARK: - Output Properties

    /// Whether this is an enrollment or authentication operation, as declared by the server.
    ///
    /// `nil` when the server sends a missing or unrecognised `operationType` — `enroll()` and
    /// `authenticate()` then fail closed with a `RecognizeError` instead of guessing.
    private(set) public var operationType: RecognizeOperationType?

    /// The raw, unparsed `operationType` string received from the server — kept only to build a
    /// useful `RecognizeError` message when it doesn't match a known `RecognizeOperationType`.
    private(set) var rawOperationType: String = ""

    /// The WebSocket URL for the Recognize authentication service.
    private(set) public var websocketURL: String = ""

    /// The customer name associated with this PingOne Recognize deployment.
    private(set) public var customerName: String = ""

    /// The public key used to encrypt images before sending them to the server.
    private(set) public var imageEncryptionPublicKey: String = ""

    /// The ID that identifies the image encryption key.
    private(set) public var imageEncryptionKeyId: String = ""

    /// The Recognize node host URL (used to configure the Keyless SDK).
    private(set) public var host: String = ""

    /// The API key for the Keyless SDK.
    private(set) public var apiKey: String = ""

    /// The username associated with the biometric operation.
    private(set) public var username: String = ""

    /// Customer-supplied transaction data to be signed by the SDK.
    private(set) public var transactionData: String = ""

    /// The intended audience for the signed JWT.
    private(set) public var audience: String = ""

    /// Whether the server requested generation of a new client state.
    private(set) public var generateClientState: Bool = false

    /// An existing client-state payload provided by the server during enrollment restore.
    private(set) public var clientState: String = ""

    /// Mobile SDK options parsed from the server response.
    private(set) public var mobileSDKOptions: RecognizeMobileSDKOptions = RecognizeMobileSDKOptions(raw: [:])

    // MARK: - Initialization

    /// Populates output properties from the JSON output fields delivered by the server.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.operationType:
            if let stringValue = value as? String {
                self.rawOperationType = stringValue
                // Exact match against "ENROLL"/"AUTHENTICATE" — matching the Android SDK's
                // `RecognizeCallback`, which does not case-normalize either. A mis-cased value
                // fails closed via `requireRecognizedOperationType()` just like an unknown one.
                self.operationType = RecognizeOperationType(rawValue: stringValue)
            }
        case JourneyConstants.websocketURL:
            if let stringValue = value as? String { self.websocketURL = stringValue }
        case JourneyConstants.customerName:
            if let stringValue = value as? String { self.customerName = stringValue }
        case JourneyConstants.imageEncryptionPublicKey:
            if let stringValue = value as? String { self.imageEncryptionPublicKey = stringValue }
        case JourneyConstants.imageEncryptionKeyId:
            if let stringValue = value as? String { self.imageEncryptionKeyId = stringValue }
        case JourneyConstants.host:
            if let stringValue = value as? String { self.host = stringValue }
        case JourneyConstants.apiKey:
            if let stringValue = value as? String { self.apiKey = stringValue }
        case JourneyConstants.username:
            if let stringValue = value as? String { self.username = stringValue }
        case JourneyConstants.transactionData:
            if let stringValue = value as? String { self.transactionData = stringValue }
        case JourneyConstants.audience:
            if let stringValue = value as? String { self.audience = stringValue }
        case JourneyConstants.generateClientState:
            if let boolValue = value as? Bool {
                self.generateClientState = boolValue
            } else if let stringValue = value as? String {
                self.generateClientState = Bool(stringValue) ?? false
            }
        case JourneyConstants.clientState:
            if let stringValue = value as? String { self.clientState = stringValue }
        case JourneyConstants.mobileSDKOptions:
            self.mobileSDKOptions = RecognizeMobileSDKOptions(raw: Self.stringDictionary(from: value))
        default:
            break
        }
    }

    // MARK: - Input Helpers

    /// Writes the error message into the `clientError` input field (suffix match).
    public func error(_ value: String) {
        updateInputValue(value, forSuffix: JourneyConstants.inputClientError)
    }

    /// Sets the signed JWT returned by the Keyless SDK into the `signedJwt` input field.
    public func setSignedJwt(_ value: String) {
        updateInputValue(value, forSuffix: JourneyConstants.inputSignedJwt)
    }

    /// Sets the client state returned by the Keyless SDK into the `clientState` input field.
    public func setClientState(_ value: String) {
        updateInputValue(value, forSuffix: JourneyConstants.inputClientState)
    }

    /// Sets the Recognize user ID into the `recognizeId` input field.
    public func setRecognizeId(_ value: String) {
        updateInputValue(value, forSuffix: JourneyConstants.inputRecognizeId)
    }

    /// Sets the device public signing key into the `devicePublicSigningKey` input field.
    public func setDevicePublicSigningKey(_ value: String) {
        updateInputValue(value, forSuffix: JourneyConstants.inputDevicePublicSigningKey)
    }

    /// Sets a client error code into the `clientErrorCode` input field.
    public func setClientErrorCode(_ value: String) {
        updateInputValue(value, forSuffix: JourneyConstants.inputClientErrorCode)
    }

    /// Writes `value` into the first input whose `name` ends with `suffix`.
    private func updateInputValue(_ value: String, forSuffix suffix: String) {
        guard var inputArray = json[JourneyConstants.input] as? [[String: Any]] else { return }
        guard let index = inputArray.firstIndex(where: {
            ($0[JourneyConstants.name] as? String)?.hasSuffix(suffix) ?? false
        }) else { return }
        inputArray[index][JourneyConstants.value] = value
        json[JourneyConstants.input] = inputArray
    }

    // MARK: - Shared Biometric Operations

    /// Sentinel `RecognizeError.code` for errors raised entirely on-device — never by the
    /// Keyless SDK, whose error codes are always non-negative.
    static let clientSideErrorCode = -1

    /// Throws a `RecognizeError` when the server's `operationType` didn't resolve to a known
    /// `RecognizeOperationType`. Called first by `enroll()` / `authenticate()` so a missing or
    /// unrecognised value fails closed instead of silently running the wrong ceremony.
    ///
    /// Mirrors the two distinct checks (and messages) in the Android SDK's `RecognizeCallback`.
    func requireRecognizedOperationType() throws {
        guard !rawOperationType.isEmpty else {
            throw RecognizeError(
                "\"operationType\" is required in the PingOneRecognizeCallback output",
                code: Self.clientSideErrorCode
            )
        }
        guard operationType != nil else {
            throw RecognizeError(
                "\"operationType\": \"\(rawOperationType)\" is not supported",
                code: Self.clientSideErrorCode
            )
        }
    }

    /// Performs the biometric enrollment operation using `BiomEnrollConfig`.
    ///
    /// Shared by `PingOneRecognizeEnrollCallback.enroll()` (plain enrollment, no override) and
    /// the not-yet-enrolled path in `PingOneRecognizeAuthenticateCallback.authenticate()`
    /// (enrollment restore, `clientStateOverride` set to the server-supplied `clientState`).
    ///
    /// On success, populates the `recognizeId`, `signedJwt`, and `clientState` input fields.
    /// The captured selfie (if `retrieveSelfie` is `true`) is returned only in the
    /// `RecognizeSuccess` to the caller — it is never written to an input field, so it never
    /// reaches Journey or the callback payload.
    open func performEnroll(
        clientStateOverride: String? = nil,
        retrieveSelfie: Bool = false,
        options: RecognizeMobileSDKOptions
    ) async throws -> RecognizeSuccess {
        let operationInfo: Keyless.OperationInfo? = options.operationInfoId.isEmpty ? nil
            : Keyless.OperationInfo(
                id: options.operationInfoId,
                payload: options.operationInfoPayload,
                externalUserId: options.operationInfoExternalUserId.isEmpty ? nil : options.operationInfoExternalUserId
            )

        let effectiveClientState = clientStateOverride ?? clientState
        let enrollConfig = BiomEnrollConfig(
            clientState: effectiveClientState.isEmpty ? nil : effectiveClientState,
            operationInfo: operationInfo,
            jwtSigningInfo: jwtSigningInfo(from: transactionData),
            livenessConfiguration: Self.enrollLivenessConfiguration(from: options.livenessConfiguration),
            livenessEnvironmentAware: options.livenessEnvironmentAware ?? BiomAuthConfig.DEFAULT_LIVENESS_ENV_AWARE,
            cameraDelaySeconds: options.cameraDelaySeconds ?? BiomEnrollConfig.DEFAULT_DELAY,
            generatingClientState: generateClientState ? .backup : nil,
            shouldRetrieveEnrollmentFrame: retrieveSelfie,
            showInstructionsScreen: options.showInstructionsScreen ?? BiomEnrollConfig.DEFAULT_SHOW_INSTRUCTIONS_SCREEN,
            showSuccessFeedback: options.showSuccessFeedback ?? BiomEnrollConfig.DEFAULT_SHOW_SUCCESS_FEEDBACK,
            showFailureFeedback: options.showFailureFeedback ?? BiomEnrollConfig.DEFAULT_SHOW_FAILURE_FEEDBACK,
            presentationStyle: Self.enrollPresentationStyle(from: options.presentation)
        )

        let enrollmentResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Keyless.EnrollmentSuccess, Error>) in
            Keyless.enroll(configuration: enrollConfig) { result in
                switch result {
                case .success(let enrollmentResult):
                    continuation.resume(returning: enrollmentResult)
                case .failure(let error):
                    if let sdkError = error as? KeylessSDKError {
                        continuation.resume(throwing: RecognizeError(
                            sdkError.message, code: sdkError.code, debuggingInfo: sdkError.debuggingInfo
                        ))
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        if let keylessId = enrollmentResult.keylessId { setRecognizeId(keylessId) }
        if let jwt = enrollmentResult.signedJwt { setSignedJwt(jwt) }
        if let state = enrollmentResult.clientState { setClientState(state) }
        return RecognizeSuccess(
            signedJwt: enrollmentResult.signedJwt,
            clientState: enrollmentResult.clientState,
            recognizeId: enrollmentResult.keylessId,
            selfie: enrollmentResult.enrollmentFrame
        )
    }

    /// Performs the biometric authentication operation using `BiomAuthConfig`.
    ///
    /// Shared by `PingOneRecognizeAuthenticateCallback.authenticate()` and the
    /// already-enrolled path within that same method. The captured selfie (if
    /// `retrieveSelfie` is `true`) is returned only in the `RecognizeSuccess` to the caller —
    /// it is never written to an input field, so it never reaches Journey or the callback payload.
    open func performAuthenticate(
        retrieveSelfie: Bool = false,
        options: RecognizeMobileSDKOptions
    ) async throws -> RecognizeSuccess {
        let operationInfo: Keyless.OperationInfo? = options.operationInfoId.isEmpty ? nil
            : Keyless.OperationInfo(
                id: options.operationInfoId,
                payload: options.operationInfoPayload,
                externalUserId: options.operationInfoExternalUserId.isEmpty ? nil : options.operationInfoExternalUserId
            )

        let authConfig = BiomAuthConfig(
            livenessConfiguration: Self.authLivenessConfiguration(from: options.livenessConfiguration),
            livenessEnvironmentAware: options.livenessEnvironmentAware ?? BiomAuthConfig.DEFAULT_LIVENESS_ENV_AWARE,
            cameraDelaySeconds: options.cameraDelaySeconds ?? BiomAuthConfig.DEFAULT_CAMERA_DELAY_SECONDS,
            generatingClientState: generateClientState ? .backup : nil,
            shouldRetrieveAuthenticationFrame: retrieveSelfie,
            showSuccessFeedback: options.showSuccessFeedback ?? BiomAuthConfig.DEFAULT_SHOW_SUCCESS_FEEDBACK,
            jwtSigningInfo: jwtSigningInfo(from: transactionData),
            operationInfo: operationInfo,
            presentationStyle: Self.authPresentationStyle(from: options.presentationStyle)
        )

        let authResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Keyless.AuthenticationSuccess, Error>) in
            Keyless.authenticate(configuration: authConfig) { result in
                switch result {
                case .success(let authResult):
                    continuation.resume(returning: authResult)
                case .failure(let error):
                    if let sdkError = error as? KeylessSDKError {
                        continuation.resume(throwing: RecognizeError(
                            sdkError.message, code: sdkError.code, debuggingInfo: sdkError.debuggingInfo
                        ))
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        if let jwt = authResult.signedJwt { setSignedJwt(jwt) }
        if let state = authResult.clientState { setClientState(state) }
        if case .success(let key) = Keyless.getDevicePublicSigningKey() {
            setDevicePublicSigningKey(key)
        }
        let userId = try? Keyless.getUserId().get()
        if let userId { setRecognizeId(userId) }
        return RecognizeSuccess(
            signedJwt: authResult.signedJwt,
            clientState: authResult.clientState,
            recognizeId: userId,
            selfie: authResult.authenticationFrame
        )
    }

    // MARK: - Keyless SDK Configuration

    /// Configures and initialises the Keyless SDK with the server-supplied credentials.
    open func configure() async throws {
        let setupConfig = SetupConfig(
            apiKey: apiKey,
            hosts: [host],
            numberOfEnrollmentCircuits: mobileSDKOptions.numberOfEnrollmentCircuits ?? SetupConfig.DEFAULT_NUMBER_OF_ENROLLMENT_CIRCUITS
        )
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Keyless.configure(setupConfiguration: setupConfig) { error in
                if let error = error {
                    continuation.resume(throwing: RecognizeError(
                        error.message, code: error.code, debuggingInfo: error.debuggingInfo
                    ))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Shared Helpers

    /// Returns a `JwtSigningInfo` when `transactionData` is non-empty; `nil` otherwise.
    public func jwtSigningInfo(from transactionData: String) -> JwtSigningInfo? {
        transactionData.isEmpty ? nil : JwtSigningInfo(claimTransactionData: transactionData, audience: audience)
    }

    /// Maps the server liveness string to `Keyless.LivenessConfiguration` for enrollment.
    /// Falls back to `BiomEnrollConfig.DEFAULT_LIVENESS_CONFIG` for unrecognised values.
    public static func enrollLivenessConfiguration(from string: String) -> Keyless.LivenessConfiguration {
        Keyless.LivenessConfiguration(rawValue: string.uppercased()) ?? BiomEnrollConfig.DEFAULT_LIVENESS_CONFIG
    }

    /// Maps the server liveness string to `Keyless.LivenessConfiguration` for authentication.
    /// Falls back to `BiomAuthConfig.DEFAULT_LIVENESS_CONFIG` for unrecognised values.
    public static func authLivenessConfiguration(from string: String) -> Keyless.LivenessConfiguration {
        Keyless.LivenessConfiguration(rawValue: string.uppercased()) ?? BiomAuthConfig.DEFAULT_LIVENESS_CONFIG
    }

    /// Records an error into the `clientError` and, if a `RecognizeError`, `clientErrorCode` input fields.
    func report(_ error: Error) {
        let message = error.localizedDescription.isEmpty
            ? JourneyConstants.clientError
            : error.localizedDescription
        self.error(message)
        if let recognizeError = error as? RecognizeError {
            setClientErrorCode(String(recognizeError.code))
        }
    }

    /// Maps the server `presentation` string to `BiomEnrollConfig.PresentationStyle`; not `RawRepresentable`, so an explicit switch is required.
    public static func enrollPresentationStyle(from string: String) -> BiomEnrollConfig.PresentationStyle {
        switch string.uppercased() {
        case "FULL_SCREEN": return .fullScreen
        case "OVERLAY":     return .overlay
        default:            return BiomEnrollConfig.DEFAULT_PRESENTATION_STYLE
        }
    }

    /// Maps the server `presentationStyle` string to `PresentationStyle`; raw values are camelCase so an explicit switch is required.
    public static func authPresentationStyle(from string: String) -> PresentationStyle {
        switch string.uppercased() {
        case "CAMERA_PREVIEW":    return .cameraPreview
        case "NO_CAMERA_PREVIEW": return .noCameraPreview
        default:                  return BiomAuthConfig.DEFAULT_PRESENTATION_STYLE
        }
    }

    /// Converts a JSON value to a `[String: String]` dictionary.
    ///
    /// Values that are not already strings are coerced via string interpolation.
    public static func stringDictionary(from value: Any) -> [String: String] {
        if let dict = value as? [String: String] { return dict }
        if let dict = value as? [String: Any] {
            return dict.reduce(into: [:]) { result, pair in
                // `pair.value as? Bool` is not a reliable boolean check: on Apple platforms,
                // any NSNumber — including a plain integer like `cameraDelaySeconds: 1` from
                // JSONSerialization — casts to Bool successfully via NSNumber.boolValue. That
                // would coerce a real "1" or "0" into "true"/"false", which `Int.init(String)`
                // then fails to parse, silently falling back to the SDK default.
                //
                // CFGetTypeID narrows the check to values that are genuinely backed by
                // CFBoolean (JSON `true`/`false`, or a native Swift `Bool`), leaving integer
                // NSNumbers to fall through to normal string interpolation below.
                if let number = pair.value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
                    result[pair.key] = number.boolValue ? "true" : "false"
                } else {
                    result[pair.key] = "\(pair.value)"
                }
            }
        }
        return [:]
    }
}

// MARK: - JourneyConstants (Recognize input field keys)

extension JourneyConstants {
    /// The string value used as a fallback client error when `localizedDescription` is empty.
    static let clientError = "clientError"
    /// Input field suffix for the signed JWT produced by the Keyless SDK.
    public static let inputSignedJwt = "signedJwt"
    /// Input field suffix for the client state produced by the Keyless SDK.
    public static let inputClientState = "clientState"
    /// Input field suffix for the Recognize user ID produced during enrollment.
    public static let inputRecognizeId = "recognizeId"
    /// Input field suffix for the device public signing key retrieved after authentication.
    public static let inputDevicePublicSigningKey = "devicePublicSigningKey"
    /// Input field suffix for the client error message.
    public static let inputClientError = "clientError"
    /// Input field suffix for a structured client error code.
    public static let inputClientErrorCode = "clientErrorCode"
}

// MARK: - JourneyConstants (Recognize output field keys + defaults)

extension JourneyConstants {
    // MARK: PingOneRecognize — output field keys

    static let operationType = "operationType"
    static let websocketURL = "websocketURL"
    static let customerName = "customerName"
    static let imageEncryptionPublicKey = "imageEncryptionPublicKey"
    static let imageEncryptionKeyId = "imageEncryptionKeyId"
    static let host = "host"
    static let apiKey = "apiKey"
    static let username = "username"
    static let transactionData = "transactionData"
    static let audience = "audience"
    static let generateClientState = "generateClientState"
    static let clientState = "clientState"
    static let mobileSDKOptions = "mobileSDKOptions"

    // MARK: PingOneRecognize — mobile SDK option keys

    static let livenessConfiguration = "livenessConfiguration"
    static let livenessEnvironmentAware = "livenessEnvironmentAware"
    static let operationInfoId = "operationInfoId"
    static let operationInfoPayload = "operationInfoPayload"
    static let operationInfoExternalUserId = "operationInfoExternalUserId"
    static let cameraDelaySeconds = "cameraDelaySeconds"
    static let showSuccessFeedback = "showSuccessFeedback"
    static let showFailureFeedback = "showFailureFeedback"
    static let showInstructionsScreen = "showInstructionsScreen"
    static let presentation = "presentation"
    static let numberOfEnrollmentCircuits = "numberOfEnrollmentCircuits"
    static let presentationStyle = "presentationStyle"
}
#endif
