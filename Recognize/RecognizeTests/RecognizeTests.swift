//
//  RecognizeTests.swift
//  RecognizeTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import KeylessSDK
@testable import PingRecognize
import PingJourneyPlugin

// MARK: - RecognizeErrorTests

final class RecognizeErrorTests: XCTestCase {

    func testInitStoresMessage() {
        let error = RecognizeError("something went wrong", code: 30000)
        XCTAssertEqual(error.message, "something went wrong")
        XCTAssertEqual(error.code, 30000)
    }

    func testErrorDescriptionMatchesMessage() {
        let error = RecognizeError("network timeout", code: 30005)
        XCTAssertEqual(error.errorDescription, "network timeout")
    }

    func testEmptyMessageIsAllowed() {
        let error = RecognizeError("", code: 0)
        XCTAssertEqual(error.message, "")
        XCTAssertEqual(error.errorDescription, "")
    }

    func testConformsToLocalizedError() {
        let error: LocalizedError = RecognizeError("test", code: 0)
        XCTAssertEqual(error.errorDescription, "test")
    }

    func testDebuggingInfoDefaultsToEmpty() {
        let error = RecognizeError("no diagnostics", code: 0)
        XCTAssertTrue(error.debuggingInfo.isEmpty)
    }

    func testDebuggingInfoStoresProvidedValues() {
        let error = RecognizeError(
            "sdk failure", code: 1,
            debuggingInfo: ["flowId": "flow-123", "sessionId": "session-456"]
        )
        XCTAssertEqual(error.debuggingInfo["flowId"], "flow-123")
        XCTAssertEqual(error.debuggingInfo["sessionId"], "session-456")
    }
}

// MARK: - RecognizeMobileSDKOptionsTests + RecognizeCallbackConstantsTests

final class RecognizeMobileSDKOptionsTests: XCTestCase {

    // MARK: Boolean computed properties

    func testBoolTrueReturnsTrueForExactString() {
        let opts = RecognizeMobileSDKOptions(raw: [
            JourneyConstants.livenessEnvironmentAware: "true",
            JourneyConstants.showSuccessFeedback: "true",
            JourneyConstants.showFailureFeedback: "true",
            JourneyConstants.showInstructionsScreen: "true",
        ])
        XCTAssertEqual(opts.livenessEnvironmentAware, true)
        XCTAssertEqual(opts.showSuccessFeedback, true)
        XCTAssertEqual(opts.showFailureFeedback, true)
        XCTAssertEqual(opts.showInstructionsScreen, true)
    }

    func testBoolFalseWhenKeyAbsent() {
        let opts = RecognizeMobileSDKOptions(raw: [:])
        XCTAssertNil(opts.livenessEnvironmentAware)
        XCTAssertNil(opts.showSuccessFeedback)
        XCTAssertNil(opts.showFailureFeedback)
        XCTAssertNil(opts.showInstructionsScreen)
    }

    func testBoolFalseForNonTrueString() {
        let opts = RecognizeMobileSDKOptions(raw: [
            JourneyConstants.livenessEnvironmentAware: "false",
            JourneyConstants.showSuccessFeedback: "false"
        ])
        XCTAssertEqual(opts.livenessEnvironmentAware, false)
        XCTAssertEqual(opts.showSuccessFeedback, false)
    }

    func testBoolFalseWhenExplicitlySetToFalse() {
        let opts = RecognizeMobileSDKOptions(raw: [
            JourneyConstants.showSuccessFeedback: "false",
            JourneyConstants.showFailureFeedback: "false",
            JourneyConstants.showInstructionsScreen: "false"
        ])
        XCTAssertEqual(opts.showSuccessFeedback, false)
        XCTAssertEqual(opts.showFailureFeedback, false)
        XCTAssertEqual(opts.showInstructionsScreen, false)
    }

    // MARK: Integer coercion

    func testCameraDelaySecondsValidInt() {
        let opts = RecognizeMobileSDKOptions(raw: [JourneyConstants.cameraDelaySeconds: "3"])
        XCTAssertEqual(opts.cameraDelaySeconds, 3)
    }

    func testCameraDelaySecondsAbsentReturnsNil() {
        let opts = RecognizeMobileSDKOptions(raw: [:])
        XCTAssertNil(opts.cameraDelaySeconds)
    }

    func testCameraDelaySecondsNonNumericReturnsNil() {
        let opts = RecognizeMobileSDKOptions(raw: [JourneyConstants.cameraDelaySeconds: "abc"])
        XCTAssertNil(opts.cameraDelaySeconds)
    }

    func testNumberOfEnrollmentCircuitsValidInt() {
        let opts = RecognizeMobileSDKOptions(raw: [JourneyConstants.numberOfEnrollmentCircuits: "7"])
        XCTAssertEqual(opts.numberOfEnrollmentCircuits, 7)
    }

    func testNumberOfEnrollmentCircuitsAbsentReturnsNil() {
        let opts = RecognizeMobileSDKOptions(raw: [:])
        XCTAssertNil(opts.numberOfEnrollmentCircuits)
    }

    func testNumberOfEnrollmentCircuitsNonNumericReturnsNil() {
        let opts = RecognizeMobileSDKOptions(raw: [JourneyConstants.numberOfEnrollmentCircuits: "nope"])
        XCTAssertNil(opts.numberOfEnrollmentCircuits)
    }

    // MARK: String properties

    func testStringPropertiesPresentReturnsValue() {
        let opts = RecognizeMobileSDKOptions(raw: [
            JourneyConstants.livenessConfiguration: "LEVEL_2",
            JourneyConstants.operationInfoId: "op-id-123",
            JourneyConstants.operationInfoPayload: "payload-abc",
            JourneyConstants.operationInfoExternalUserId: "user-xyz",
            JourneyConstants.presentation: "OVERLAY",
            JourneyConstants.presentationStyle: "CAMERA_PREVIEW"
        ])
        XCTAssertEqual(opts.livenessConfiguration, "LEVEL_2")
        XCTAssertEqual(opts.operationInfoId, "op-id-123")
        XCTAssertEqual(opts.operationInfoPayload, "payload-abc")
        XCTAssertEqual(opts.operationInfoExternalUserId, "user-xyz")
        XCTAssertEqual(opts.presentation, "OVERLAY")
        XCTAssertEqual(opts.presentationStyle, "CAMERA_PREVIEW")
    }

    func testStringPropertiesAbsentReturnEmptyString() {
        let opts = RecognizeMobileSDKOptions(raw: [:])
        XCTAssertEqual(opts.livenessConfiguration, "")
        XCTAssertEqual(opts.operationInfoId, "")
        XCTAssertEqual(opts.operationInfoPayload, "")
        XCTAssertEqual(opts.operationInfoExternalUserId, "")
        XCTAssertEqual(opts.presentation, "")
        XCTAssertEqual(opts.presentationStyle, "")
    }
}

// MARK: - RecognizeCallbackInitValueTests

final class RecognizeCallbackInitValueTests: XCTestCase {

    // MARK: operationType

    func testInitValueOperationTypeEnroll() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.operationType, value: "ENROLL")
        XCTAssertEqual(callback.operationType, .enroll)
    }

    func testInitValueOperationTypeAuthenticate() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.operationType, value: "AUTHENTICATE")
        XCTAssertEqual(callback.operationType, .authenticate)
    }

    func testInitValueOperationTypeUnknownStaysNil() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.operationType, value: "UNKNOWN")
        XCTAssertNil(callback.operationType)
    }

    func testInitValueOperationTypeMixedCaseIsRejected() {
        // Exact match only, matching the Android SDK — no case normalization.
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.operationType, value: "authenticate")
        XCTAssertNil(callback.operationType)
    }

    // MARK: String output fields

    func testInitValueWebsocketURL() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.websocketURL, value: "wss://example.com/ws")
        XCTAssertEqual(callback.websocketURL, "wss://example.com/ws")
    }

    func testInitValueCustomerName() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.customerName, value: "Acme Corp")
        XCTAssertEqual(callback.customerName, "Acme Corp")
    }

    func testInitValueImageEncryptionPublicKey() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.imageEncryptionPublicKey, value: "MFwwDQYJ")
        XCTAssertEqual(callback.imageEncryptionPublicKey, "MFwwDQYJ")
    }

    func testInitValueImageEncryptionKeyId() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.imageEncryptionKeyId, value: "key-id-007")
        XCTAssertEqual(callback.imageEncryptionKeyId, "key-id-007")
    }

    func testInitValueHost() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.host, value: "https://recognize.ping.com")
        XCTAssertEqual(callback.host, "https://recognize.ping.com")
    }

    func testInitValueApiKey() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.apiKey, value: "api-key-abc")
        XCTAssertEqual(callback.apiKey, "api-key-abc")
    }

    func testInitValueUsername() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.username, value: "testuser")
        XCTAssertEqual(callback.username, "testuser")
    }

    func testInitValueTransactionData() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.transactionData, value: "tx-data-payload")
        XCTAssertEqual(callback.transactionData, "tx-data-payload")
    }

    func testInitValueGenerateClientStateString() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.generateClientState, value: "true")
        XCTAssertTrue(callback.generateClientState)
    }

    func testInitValueGenerateClientStateBoolTrue() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.generateClientState, value: true)
        XCTAssertTrue(callback.generateClientState)
    }

    func testInitValueGenerateClientStateBoolFalse() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.generateClientState, value: false)
        XCTAssertFalse(callback.generateClientState)
    }

    func testInitValueClientState() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.clientState, value: "client-state-blob")
        XCTAssertEqual(callback.clientState, "client-state-blob")
    }

    // MARK: mobileSDKOptions

    func testInitValueMobileSDKOptionsStringDict() {
        let callback = RecognizeCallback()
        let raw: [String: Any] = [
            JourneyConstants.livenessConfiguration: "LEVEL_1",
            JourneyConstants.livenessEnvironmentAware: "true"
        ]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: raw)
        XCTAssertEqual(callback.mobileSDKOptions.livenessConfiguration, "LEVEL_1")
        XCTAssertEqual(callback.mobileSDKOptions.livenessEnvironmentAware, true)
    }

    func testInitValueMobileSDKOptionsNonStringValuesCoerced() {
        let callback = RecognizeCallback()
        let raw: [String: Any] = [JourneyConstants.cameraDelaySeconds: 4]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: raw)
        // The value 4 is coerced to "4" via string interpolation; Int("4") == 4
        XCTAssertEqual(callback.mobileSDKOptions.cameraDelaySeconds, 4)
    }

    func testInitValueMobileSDKOptionsUnknownCustomSecretIsIgnored() {
        let callback = RecognizeCallback()
        let raw: [String: Any] = ["customSecret": "server-secret"]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: raw)
        XCTAssertEqual(callback.mobileSDKOptions.livenessConfiguration, "")
        XCTAssertNil(callback.mobileSDKOptions.cameraDelaySeconds)
    }

    func testInitValueMobileSDKOptionsEmptyDictProducesNilForOptionals() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: [String: Any]())
        XCTAssertNil(callback.mobileSDKOptions.livenessEnvironmentAware)
        XCTAssertNil(callback.mobileSDKOptions.cameraDelaySeconds)
        XCTAssertNil(callback.mobileSDKOptions.numberOfEnrollmentCircuits)
    }

    func testInitValueUnknownKeyIsIgnored() {
        let callback = RecognizeCallback()
        // Should not crash; all properties retain their defaults.
        callback.initValue(name: "unknownOutputField", value: "irrelevant")
        XCTAssertNil(callback.operationType)
        XCTAssertEqual(callback.websocketURL, "")
    }

    func testInitValueWrongTypeForStringFieldIsIgnored() {
        let callback = RecognizeCallback()
        // Passing a non-String for a string field — the guard `value as? String` should fail silently.
        callback.initValue(name: JourneyConstants.websocketURL, value: 42)
        XCTAssertEqual(callback.websocketURL, "")
    }
}

// MARK: - RecognizeCallbackInputSetterTests

final class RecognizeCallbackInputSetterTests: XCTestCase {

    /// Builds a RecognizeCallback whose `json` already contains an `input` array
    /// with all six Recognize input keys — mirrors what the Journey framework delivers.
    private func makeCallback() async -> RecognizeCallback {
        let inputKeys = [
            JourneyConstants.inputSignedJwt,
            JourneyConstants.inputClientState,
            JourneyConstants.inputRecognizeId,
            JourneyConstants.inputDevicePublicSigningKey,
            JourneyConstants.inputClientError,
            JourneyConstants.inputClientErrorCode
        ]
        let inputArray = inputKeys.map { ["name": $0, "value": ""] }
        let json: [String: Any] = ["input": inputArray, "output": [], "type": "PingOneRecognizeCallback"]
        let callback = RecognizeCallback()
        _ = await callback.initialize(with: json)
        return callback
    }

    private func inputValue(for key: String, in callback: RecognizeCallback) -> String? {
        guard let inputs = callback.json["input"] as? [[String: Any]] else { return nil }
        return inputs.first(where: { ($0["name"] as? String) == key })?["value"] as? String
    }

    func testSetSignedJwt() async {
        let callback = await makeCallback()
        callback.setSignedJwt("jwt-token-xyz")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputSignedJwt, in: callback), "jwt-token-xyz")
    }

    func testSetClientState() async {
        let callback = await makeCallback()
        callback.setClientState("state-blob")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientState, in: callback), "state-blob")
    }

    func testSetRecognizeId() async {
        let callback = await makeCallback()
        callback.setRecognizeId("recognize-id-001")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputRecognizeId, in: callback), "recognize-id-001")
    }

    func testSetDevicePublicSigningKey() async {
        let callback = await makeCallback()
        callback.setDevicePublicSigningKey("public-key-pem")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputDevicePublicSigningKey, in: callback), "public-key-pem")
    }

    func testSetClientErrorCode() async {
        let callback = await makeCallback()
        callback.setClientErrorCode("ERR_001")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: callback), "ERR_001")
    }

    func testErrorHelper() async {
        let callback = await makeCallback()
        callback.error("something went wrong")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: callback), "something went wrong")
    }
}

// MARK: - StringDictionaryTests

final class StringDictionaryTests: XCTestCase {

    func testStringStringDictPassthroughUnchanged() {
        let callback = RecognizeCallback()
        let input: [String: Any] = ["key1": "value1", "key2": "value2"]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: input)
        XCTAssertEqual(callback.mobileSDKOptions.operationInfoId, "")
        XCTAssertEqual(callback.mobileSDKOptions.livenessConfiguration, "")
    }

    func testStringAnyDictWithNonStringValuesCoerced() {
        let callback = RecognizeCallback()
        let input: [String: Any] = [
            JourneyConstants.cameraDelaySeconds: 3,
            JourneyConstants.numberOfEnrollmentCircuits: 7
        ]
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: input)
        XCTAssertEqual(callback.mobileSDKOptions.cameraDelaySeconds, 3)
        XCTAssertEqual(callback.mobileSDKOptions.numberOfEnrollmentCircuits, 7)
    }

    func testNonDictValueProducesEmptyOptions() {
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: "not-a-dict")
        XCTAssertNil(callback.mobileSDKOptions.cameraDelaySeconds)
        XCTAssertNil(callback.mobileSDKOptions.numberOfEnrollmentCircuits)
        XCTAssertNil(callback.mobileSDKOptions.livenessEnvironmentAware)
    }

    func testNSCFBooleanFalseCoercedCorrectly() throws {
        // JSONSerialization produces __NSCFBoolean, which interpolates as "0"/"1".
        // Verify that false JSON booleans are coerced to "false", not "0".
        let json = """
        {"showInstructionsScreen": false, "showSuccessFeedback": false, "livenessEnvironmentAware": false}
        """.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: parsed)
        XCTAssertEqual(callback.mobileSDKOptions.showInstructionsScreen, false)
        XCTAssertEqual(callback.mobileSDKOptions.showSuccessFeedback, false)
        XCTAssertEqual(callback.mobileSDKOptions.livenessEnvironmentAware, false)
    }

    func testNSCFBooleanTrueCoercedCorrectly() throws {
        let json = """
        {"showInstructionsScreen": true, "showSuccessFeedback": true, "livenessEnvironmentAware": true}
        """.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: parsed)
        XCTAssertEqual(callback.mobileSDKOptions.showInstructionsScreen, true)
        XCTAssertEqual(callback.mobileSDKOptions.showSuccessFeedback, true)
        XCTAssertEqual(callback.mobileSDKOptions.livenessEnvironmentAware, true)
    }

    func testIntegerZeroAndOneAreNotMistakenForBooleans() throws {
        // Regression test: NSNumber(1)/NSNumber(0) from JSONSerialization must NOT be
        // coerced to "true"/"false" just because `as? Bool` succeeds for any NSNumber on
        // Apple platforms — only genuine CFBoolean-backed values should be.
        let json = """
        {"cameraDelaySeconds": 1, "numberOfEnrollmentCircuits": 0, "showSuccessFeedback": true}
        """.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        let callback = RecognizeCallback()
        callback.initValue(name: JourneyConstants.mobileSDKOptions, value: parsed)
        XCTAssertEqual(callback.mobileSDKOptions.cameraDelaySeconds, 1)
        XCTAssertEqual(callback.mobileSDKOptions.numberOfEnrollmentCircuits, 0)
        XCTAssertEqual(callback.mobileSDKOptions.showSuccessFeedback, true)
    }
}


// MARK: - EnrollWithClientStateTests

final class EnrollWithClientStateTests: XCTestCase {

    func testClientStateAbsentRoutesToAuthenticateBranch() async {
        let inputKeys = [
            JourneyConstants.inputSignedJwt,
            JourneyConstants.inputClientState,
            JourneyConstants.inputRecognizeId,
            JourneyConstants.inputDevicePublicSigningKey,
            JourneyConstants.inputClientError,
            JourneyConstants.inputClientErrorCode
        ]
        let inputArray = inputKeys.map { ["name": $0, "value": ""] }
        let outputArray: [[String: Any]] = [
            ["name": JourneyConstants.operationType, "value": "AUTHENTICATE"]
        ]
        let json: [String: Any] = [
            "input": inputArray,
            "output": outputArray,
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let callback = RecognizeCallback()
        _ = await callback.initialize(with: json)

        XCTAssertEqual(callback.clientState, "")
        XCTAssertEqual(callback.operationType, .authenticate)

        let inputs = callback.json["input"] as? [[String: Any]]
        let recognizeIdValue = inputs?.first(where: { ($0["name"] as? String) == JourneyConstants.inputRecognizeId })?["value"] as? String
        XCTAssertEqual(recognizeIdValue, "")
    }
}

// MARK: - RecognizeOperationTypeTests

final class RecognizeOperationTypeTests: XCTestCase {

    func testRawValueEnroll() {
        XCTAssertEqual(RecognizeOperationType.enroll.rawValue, "ENROLL")
    }

    func testRawValueAuthenticate() {
        XCTAssertEqual(RecognizeOperationType.authenticate.rawValue, "AUTHENTICATE")
    }

    func testInitFromRawValueEnroll() {
        XCTAssertEqual(RecognizeOperationType(rawValue: "ENROLL"), .enroll)
    }

    func testInitFromRawValueAuthenticate() {
        XCTAssertEqual(RecognizeOperationType(rawValue: "AUTHENTICATE"), .authenticate)
    }

    func testInitFromRawValueUnknownReturnsNil() {
        XCTAssertNil(RecognizeOperationType(rawValue: "UNKNOWN"))
    }
}

// MARK: - Testable subclasses (injectable Keyless seam)

/// Subclass that replaces `configure()` and `performEnroll()` with configurable outcomes.
/// Used to test error-propagation without invoking the real Keyless SDK.
class TestableEnrollCallback: PingOneRecognizeEnrollCallback {
    var configureResult: Error? = nil
    var enrollResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: "state", recognizeId: "rid", selfie: nil))
    private(set) var capturedRetrieveSelfie: Bool?

    override func configure() async throws {
        if let error = configureResult { throw error }
    }

    override func performEnroll(clientStateOverride: String?, retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        capturedRetrieveSelfie = retrieveSelfie
        switch enrollResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

/// Subclass that replaces `configure()`, `performAuthenticate()`, and the enrollment-restore
/// dispatch (`enrollWithClientStateIfNeeded`) with configurable outcomes — used to test
/// `authenticate()`'s top-level clientState-empty-vs-non-empty routing in isolation.
class TestableAuthCallback: PingOneRecognizeAuthenticateCallback {
    var configureResult: Error? = nil
    var performAuthenticateResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: nil, recognizeId: nil, selfie: nil))
    var enrollWithClientStateIfNeededResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: "state", recognizeId: nil, selfie: nil))
    private(set) var capturedRetrieveSelfie: Bool?

    override func configure() async throws {
        if let error = configureResult { throw error }
    }

    override func performAuthenticate(retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        capturedRetrieveSelfie = retrieveSelfie
        switch performAuthenticateResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }

    override func enrollWithClientStateIfNeeded(_ clientState: String, retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        capturedRetrieveSelfie = retrieveSelfie
        switch enrollWithClientStateIfNeededResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

/// Subclass that overrides only `validateUserDeviceActive`, `performEnroll`, and
/// `performAuthenticate`, leaving the real `enrollWithClientStateIfNeeded` switch logic
/// intact so its routing can be tested.
class TestableValidationAuthCallback: PingOneRecognizeAuthenticateCallback {
    var configureResult: Error? = nil
    var validateResult: PingOneRecognizeAuthenticateCallback.ValidationResult = .notEnrolled
    var performEnrollResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: nil, recognizeId: "rid", selfie: nil))
    var performAuthenticateResult: Result<RecognizeSuccess, Error> = .success(RecognizeSuccess(signedJwt: "jwt", clientState: nil, recognizeId: nil, selfie: nil))

    override func configure() async throws {
        if let error = configureResult { throw error }
    }

    override func validateUserDeviceActive() async -> PingOneRecognizeAuthenticateCallback.ValidationResult {
        validateResult
    }

    override func performEnroll(clientStateOverride: String?, retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        switch performEnrollResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }

    override func performAuthenticate(retrieveSelfie: Bool, options: RecognizeMobileSDKOptions) async throws -> RecognizeSuccess {
        switch performAuthenticateResult {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

// MARK: - ExecutePathTests

final class ExecutePathTests: XCTestCase {

    private func inputArrayWith(keys: [String]) -> [[String: Any]] {
        keys.map { ["name": $0, "value": ""] }
    }

    private func inputValue(for key: String, in callback: AbstractRecognizeCallback) -> String? {
        guard let inputs = callback.json["input"] as? [[String: Any]] else { return nil }
        return inputs.first(where: { ($0["name"] as? String) == key })?["value"] as? String
    }

    /// - Parameter operationType: The `operationType` output value to send, or `nil` to omit
    ///   the field entirely (simulating a server response that never sets it).
    private func makeEnrollCallback(operationType: String? = "ENROLL") async -> TestableEnrollCallback {
        let inputKeys = [JourneyConstants.inputSignedJwt, JourneyConstants.inputClientState,
                         JourneyConstants.inputRecognizeId, JourneyConstants.inputDevicePublicSigningKey,
                         JourneyConstants.inputClientError, JourneyConstants.inputClientErrorCode]
        var output: [[String: Any]] = []
        if let operationType {
            output.append(["name": JourneyConstants.operationType, "value": operationType])
        }
        let json: [String: Any] = [
            "input": inputArrayWith(keys: inputKeys),
            "output": output,
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let cb = TestableEnrollCallback()
        _ = await cb.initialize(with: json)
        return cb
    }

    /// - Parameter operationType: The `operationType` output value to send, or `nil` to omit
    ///   the field entirely (simulating a server response that never sets it).
    private func makeAuthCallback(clientState: String = "", operationType: String? = "AUTHENTICATE") async -> TestableAuthCallback {
        let inputKeys = [JourneyConstants.inputSignedJwt, JourneyConstants.inputClientState,
                         JourneyConstants.inputRecognizeId, JourneyConstants.inputDevicePublicSigningKey,
                         JourneyConstants.inputClientError, JourneyConstants.inputClientErrorCode]
        var output: [[String: Any]] = []
        if let operationType {
            output.append(["name": JourneyConstants.operationType, "value": operationType])
        }
        if !clientState.isEmpty {
            output.append(["name": JourneyConstants.clientState, "value": clientState])
        }
        let json: [String: Any] = [
            "input": inputArrayWith(keys: inputKeys),
            "output": output,
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let cb = TestableAuthCallback()
        _ = await cb.initialize(with: json)
        if !clientState.isEmpty {
            cb.initValue(name: JourneyConstants.clientState, value: clientState)
        }
        return cb
    }

    // MARK: operationType fail-closed

    func testEnrollFailsClosedWhenOperationTypeMissing() async {
        let cb = await makeEnrollCallback(operationType: nil)
        let result = await cb.enroll()
        guard case .failure(let error) = result else { return XCTFail("Expected failure") }
        XCTAssertEqual((error as? RecognizeError)?.code, AbstractRecognizeCallback.clientSideErrorCode)
        // Mirrors Android's `require(operationType.isNotEmpty())` message.
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "\"operationType\" is required in the PingOneRecognizeCallback output")
    }

    func testEnrollFailsClosedWhenOperationTypeUnrecognized() async {
        let cb = await makeEnrollCallback()
        cb.initValue(name: JourneyConstants.operationType, value: "SOMETHING_ELSE")
        let result = await cb.enroll()
        guard case .failure(let error) = result else { return XCTFail("Expected failure") }
        XCTAssertEqual((error as? RecognizeError)?.code, AbstractRecognizeCallback.clientSideErrorCode)
        // Mirrors Android's `else -> throw IllegalArgumentException("...is not supported")` message.
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "\"operationType\": \"SOMETHING_ELSE\" is not supported")
    }

    func testEnrollFailsClosedWhenOperationTypeMixedCase() async {
        let cb = await makeEnrollCallback()
        cb.initValue(name: JourneyConstants.operationType, value: "enroll")
        let result = await cb.enroll()
        guard case .failure = result else { return XCTFail("Expected failure — exact match only, no case normalization") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "\"operationType\": \"enroll\" is not supported")
    }

    func testAuthenticateFailsClosedWhenOperationTypeMissing() async {
        let cb = await makeAuthCallback(operationType: nil)
        let result = await cb.authenticate()
        guard case .failure(let error) = result else { return XCTFail("Expected failure") }
        XCTAssertEqual((error as? RecognizeError)?.code, AbstractRecognizeCallback.clientSideErrorCode)
        XCTAssertNotNil(inputValue(for: JourneyConstants.inputClientError, in: cb))
    }

    // MARK: configure() failure

    func testEnrollConfigureFailurePopulatesClientError() async {
        let cb = await makeEnrollCallback()
        cb.configureResult = RecognizeError("sdk setup failed", code: 10001)
        let result = await cb.enroll()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "sdk setup failed")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "10001")
    }

    func testAuthConfigureFailurePopulatesClientError() async {
        let cb = await makeAuthCallback()
        cb.configureResult = RecognizeError("setup error", code: 20002)
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "setup error")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "20002")
    }

    // MARK: enroll() failure

    func testEnrollFailurePopulatesClientErrorAndCode() async {
        let cb = await makeEnrollCallback()
        cb.enrollResult = .failure(RecognizeError("enroll failed", code: 30001))
        let result = await cb.enroll()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "enroll failed")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "30001")
    }

    func testEnrollSuccessReturnsResult() async {
        let cb = await makeEnrollCallback()
        cb.enrollResult = .success(RecognizeSuccess(signedJwt: "signed-token", clientState: nil, recognizeId: "rec-123", selfie: nil))
        let result = await cb.enroll()
        guard case .success(let r) = result else { return XCTFail("Expected success") }
        XCTAssertEqual(r.signedJwt, "signed-token")
        XCTAssertEqual(r.recognizeId, "rec-123")
    }

    // MARK: retrieveSelfie — always an explicit, app-level decision (never from mobileSDKOptions)

    func testEnrollRetrieveSelfieDefaultsToFalse() async {
        let cb = await makeEnrollCallback()
        _ = await cb.enroll()
        XCTAssertEqual(cb.capturedRetrieveSelfie, false)
    }

    func testEnrollRetrieveSelfiePassedThroughWhenSetInConfig() async {
        let cb = await makeEnrollCallback()
        _ = await cb.enroll { $0.retrieveSelfie = true }
        XCTAssertEqual(cb.capturedRetrieveSelfie, true)
    }

    // MARK: enrollWithClientStateIfNeeded() failure — owned by the Authenticate callback,
    // matching Android (the AUTHENTICATE server operationType always maps to
    // PingOneRecognizeAuthenticateCallback; the enrollment-restore decision lives inside it).

    func testEnrollWithClientStateFailurePopulatesClientError() async {
        let cb = await makeAuthCallback(clientState: "existing-state")
        cb.enrollWithClientStateIfNeededResult = .failure(RecognizeError("restore failed", code: 40001))
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "restore failed")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "40001")
    }

    func testEnrollWithClientStateSuccessReturnsResult() async {
        let cb = await makeAuthCallback(clientState: "existing-state")
        cb.enrollWithClientStateIfNeededResult = .success(RecognizeSuccess(signedJwt: "jwt-restore", clientState: "new-state", recognizeId: nil, selfie: nil))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success") }
        XCTAssertEqual(r.signedJwt, "jwt-restore")
        XCTAssertEqual(r.clientState, "new-state")
    }

    // MARK: performAuthenticate() failure

    func testAuthFailurePopulatesClientErrorAndCode() async {
        let cb = await makeAuthCallback()
        cb.performAuthenticateResult = .failure(RecognizeError("auth failed", code: 50001))
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "auth failed")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "50001")
    }

    func testAuthSuccessReturnsResult() async {
        let cb = await makeAuthCallback()
        cb.performAuthenticateResult = .success(RecognizeSuccess(signedJwt: "auth-jwt", clientState: "auth-state", recognizeId: nil, selfie: nil))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success") }
        XCTAssertEqual(r.signedJwt, "auth-jwt")
        XCTAssertEqual(r.clientState, "auth-state")
    }

    // MARK: retrieveSelfie — always an explicit, app-level decision (never from mobileSDKOptions)

    func testAuthRetrieveSelfieDefaultsToFalse() async {
        let cb = await makeAuthCallback()
        _ = await cb.authenticate()
        XCTAssertEqual(cb.capturedRetrieveSelfie, false)
    }

    func testAuthRetrieveSelfiePassedThroughWhenSetInConfig() async {
        let cb = await makeAuthCallback()
        _ = await cb.authenticate { $0.retrieveSelfie = true }
        XCTAssertEqual(cb.capturedRetrieveSelfie, true)
    }

    func testEnrollWithClientStateRetrieveSelfiePassedThrough() async {
        let cb = await makeAuthCallback(clientState: "existing-state")
        _ = await cb.authenticate { $0.retrieveSelfie = true }
        XCTAssertEqual(cb.capturedRetrieveSelfie, true)
    }

    // MARK: clientState routing (inside PingOneRecognizeAuthenticateCallback.authenticate())

    func testEmptyClientStateRoutesToAuthenticate() async {
        let cb = await makeAuthCallback()
        // performAuthenticateResult is success; enrollWithClientStateIfNeededResult would fail if wrongly called
        cb.performAuthenticateResult = .success(RecognizeSuccess(signedJwt: "auth-jwt", clientState: nil, recognizeId: nil, selfie: nil))
        cb.enrollWithClientStateIfNeededResult = .failure(RecognizeError("should not be called", code: 9999))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success via authenticate path") }
        XCTAssertEqual(r.signedJwt, "auth-jwt")
    }

    func testNonEmptyClientStateRoutesToEnrollWithClientStateIfNeeded() async {
        let cb = await makeAuthCallback(clientState: "existing-state")
        // enrollWithClientStateIfNeededResult is success; performAuthenticateResult would fail if wrongly called
        cb.enrollWithClientStateIfNeededResult = .success(RecognizeSuccess(signedJwt: "restore-jwt", clientState: "new-state", recognizeId: nil, selfie: nil))
        cb.performAuthenticateResult = .failure(RecognizeError("should not be called", code: 9999))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success via enrollWithClientStateIfNeeded path") }
        XCTAssertEqual(r.signedJwt, "restore-jwt")
    }

    // MARK: non-RecognizeError propagation

    func testNonRecognizeErrorUsesLocalizedDescription() async {
        struct PlainError: LocalizedError {
            var errorDescription: String? { "plain error message" }
        }
        let cb = await makeAuthCallback()
        cb.performAuthenticateResult = .failure(PlainError())
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "plain error message")
        // No error code set for non-RecognizeError
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "")
    }

    // MARK: validateUserDeviceActive routing inside enrollWithClientStateIfNeeded

    private func makeValidationCallback(clientState: String = "existing-state") async -> TestableValidationAuthCallback {
        let inputKeys = [JourneyConstants.inputSignedJwt, JourneyConstants.inputClientState,
                         JourneyConstants.inputRecognizeId, JourneyConstants.inputDevicePublicSigningKey,
                         JourneyConstants.inputClientError, JourneyConstants.inputClientErrorCode]
        let json: [String: Any] = [
            "input": inputArrayWith(keys: inputKeys),
            "output": [["name": JourneyConstants.operationType, "value": "AUTHENTICATE"]],
            "type": JourneyConstants.pingOneRecognizeCallback
        ]
        let cb = TestableValidationAuthCallback()
        _ = await cb.initialize(with: json)
        cb.initValue(name: JourneyConstants.clientState, value: clientState)
        return cb
    }

    func testValidationActiveRoutesToAuthenticate() async {
        let cb = await makeValidationCallback()
        cb.validateResult = .active
        cb.performAuthenticateResult = .success(RecognizeSuccess(signedJwt: "auth-jwt", clientState: nil, recognizeId: nil, selfie: nil))
        // performEnrollResult would fail if wrongly called
        cb.performEnrollResult = .failure(RecognizeError("should not enroll", code: 9999))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success via authenticate path") }
        XCTAssertEqual(r.signedJwt, "auth-jwt")
    }

    func testValidationNotEnrolledRoutesToEnroll() async {
        let cb = await makeValidationCallback()
        cb.validateResult = .notEnrolled
        cb.performEnrollResult = .success(RecognizeSuccess(signedJwt: "enroll-jwt", clientState: nil, recognizeId: "rid", selfie: nil))
        // performAuthenticateResult would fail if wrongly called
        cb.performAuthenticateResult = .failure(RecognizeError("should not authenticate", code: 9999))
        let result = await cb.authenticate()
        guard case .success(let r) = result else { return XCTFail("Expected success via enroll path") }
        XCTAssertEqual(r.signedJwt, "enroll-jwt")
    }

    func testValidationOtherErrorPropagatesWithoutEnrolling() async {
        let cb = await makeValidationCallback()
        cb.validateResult = .otherError(message: "device locked", code: 60001)
        // Neither performEnroll nor performAuthenticate should be called
        cb.performEnrollResult = .failure(RecognizeError("should not enroll", code: 9999))
        cb.performAuthenticateResult = .failure(RecognizeError("should not authenticate", code: 9999))
        let result = await cb.authenticate()
        guard case .failure = result else { return XCTFail("Expected failure") }
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientError, in: cb), "device locked")
        XCTAssertEqual(inputValue(for: JourneyConstants.inputClientErrorCode, in: cb), "60001")
    }
}
