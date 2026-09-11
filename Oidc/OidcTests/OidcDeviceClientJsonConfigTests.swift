//
//  OidcDeviceClientJsonConfigTests.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOidc
@testable import PingLogger

final class OidcDeviceClientJsonConfigTests: XCTestCase, @unchecked Sendable {

    private var minimalJson: [String: Any] {
        [
            "oidc": [
                "clientId": "my-client",
                "discoveryEndpoint": "https://example.com/.well-known/openid-configuration",
                "scopes": ["openid"],
                "redirectUri": "myapp://callback"
            ] as [String: Any]
        ]
    }

    private var fullJson: [String: Any] {
        [
            "log": "DEBUG",
            "oidc": [
                "clientId": "my-client",
                "discoveryEndpoint": "https://example.com/.well-known/openid-configuration",
                "scopes": ["openid", "profile", "email"],
                "redirectUri": "myapp://callback",
                "signOutRedirectUri": "myapp://logout",
                "refreshThreshold": 30,
                "acrValues": "Level3",
                "additionalParameters": ["custom": "value"],
                "openId": [
                    "deviceAuthorizationEndpoint": "https://example.com/device/code"
                ] as [String: Any]
            ] as [String: Any]
        ]
    }

    /// No `discoveryEndpoint` — the `openId` sub-object stands in for the discovery document.
    private var openIdOnlyJson: [String: Any] {
        [
            "oidc": [
                "clientId": "my-client",
                "scopes": ["openid"],
                "redirectUri": "myapp://callback",
                "openId": [
                    "authorizationEndpoint": "https://example.com/authorize",
                    "tokenEndpoint": "https://example.com/token"
                ] as [String: Any]
            ] as [String: Any]
        ]
    }

    /// Parses the `oidc` sub-dictionary through the same entry point the factories use, so the
    /// resulting `OidcClientConfig` can be inspected (the client keeps its config private).
    private func parseOidcConfig(_ json: [String: Any]) throws -> OidcClientConfig {
        let oidc = json["oidc"] as! [String: Any]
        return try OidcClientConfig.from(oidcJson: oidc, logger: LogManager.none)
    }

    // MARK: - Success cases

    func testCreateOidcDeviceClient_success_minimalRequiredFields() {
        let result = OidcDeviceClient.createOidcDeviceClient(json: minimalJson)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success, got: \(error)")
        }
    }

    func testCreateOidcDeviceClient_success_allFields() {
        let result = OidcDeviceClient.createOidcDeviceClient(json: fullJson)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success, got: \(error)")
        }
    }

    func testCreateOidcDeviceClient_unknownFieldsSilentlyIgnored() {
        var json = minimalJson
        json["unknownTopLevel"] = "ignored"
        var oidc = json["oidc"] as! [String: Any]
        oidc["unknownOidcField"] = 42
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Unknown fields should be silently ignored, got: \(error)")
        }
    }

    func testCreateOidcDeviceClient_journeyFieldsSilentlyIgnored() {
        var json = minimalJson
        json["serverUrl"] = "https://example.com/am"
        json["realm"] = "alpha"
        json["cookieName"] = "iPlanetDirectoryPro"

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Journey-specific fields should be silently ignored, got: \(error)")
        }
    }

    // MARK: - timeout

    func testCreateOidcDeviceClient_timeout_validInteger_succeeds() {
        var json = minimalJson
        json["timeout"] = 20000

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success with valid timeout, got: \(error)")
        }
    }

    func testCreateOidcDeviceClient_timeout_absent_succeeds() {
        let result = OidcDeviceClient.createOidcDeviceClient(json: minimalJson)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success when timeout absent, got: \(error)")
        }
    }

    // MARK: - log

    func testCreateOidcDeviceClient_logMapping_debug() {
        var json = minimalJson
        json["log"] = "DEBUG"

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(client.logger is StandardLogger)
    }

    func testCreateOidcDeviceClient_logMapping_warn() {
        var json = minimalJson
        json["log"] = "WARN"

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(client.logger is WarningLogger)
    }

    func testCreateOidcDeviceClient_logWrongType_softFault_succeeds() {
        var json = minimalJson
        json["log"] = 1

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success when log has wrong type (soft fault), got: \(error)")
        }
    }

    // MARK: - oidc (required)

    func testCreateOidcDeviceClient_failure_missingOidc() {
        var json = minimalJson
        json.removeValue(forKey: "oidc")

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc")
    }

    func testCreateOidcDeviceClient_failure_oidcWrongType() {
        var json = minimalJson
        json["oidc"] = "not-an-object"

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc")
    }

    // MARK: - Required OIDC fields

    func testCreateOidcDeviceClient_failure_missingClientId() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "clientId")
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.clientId), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.clientId")
    }

    func testCreateOidcDeviceClient_failure_missingDiscoveryEndpoint() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "discoveryEndpoint")
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    func testCreateOidcDeviceClient_failure_missingScopes() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "scopes")
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.scopes), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    func testCreateOidcDeviceClient_failure_missingRedirectUri() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "redirectUri")
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.redirectUri), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.redirectUri")
    }

    func testCreateOidcDeviceClient_failure_scopesNotStringArray() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["scopes"] = [1, 2, 3]
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.scopes), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    // MARK: - openId endpoint overrides

    func testCreateOidcDeviceClient_openId_absent_succeeds() {
        let result = OidcDeviceClient.createOidcDeviceClient(json: minimalJson)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success when openId absent, got: \(error)")
        }
    }

    func testCreateOidcDeviceClient_openId_deviceAuthorizationEndpoint_accepted() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = ["deviceAuthorizationEndpoint": "https://example.com/device/code"] as [String: Any]
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success with deviceAuthorizationEndpoint, got: \(error)")
        }
    }

    func testCreateOidcDeviceClient_failure_openIdWrongType() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = "not-an-object"
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(openId), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.openId")
    }

    func testCreateOidcDeviceClient_failure_openId_deviceAuthorizationEndpoint_wrongType() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = ["deviceAuthorizationEndpoint": 123] as [String: Any]
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.openId.deviceAuthorizationEndpoint), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.openId.deviceAuthorizationEndpoint")
    }

    func testCreateOidcDeviceClient_openId_unknownKeysSilentlyIgnored() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = ["unknownEndpoint": "https://example.com/unknown"] as [String: Any]
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Unknown openId keys should be silently ignored, got: \(error)")
        }
    }

    // MARK: - openId as a replacement for the discovery document

    func testCreateOidcDeviceClient_openIdWithoutDiscoveryEndpoint_succeeds() throws {
        let result = OidcDeviceClient.createOidcDeviceClient(json: openIdOnlyJson)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success with openId and no discoveryEndpoint, got: \(error)")
        }

        let config = try parseOidcConfig(openIdOnlyJson)
        let openId = try XCTUnwrap(config.openId, "openId should stand in for the discovery document")
        XCTAssertEqual(openId.authorizationEndpoint, "https://example.com/authorize")
        XCTAssertEqual(openId.tokenEndpoint, "https://example.com/token")
        // Every other non-optional endpoint defaults to "" and the optional ones to nil.
        XCTAssertEqual(openId.userinfoEndpoint, "")
        XCTAssertEqual(openId.endSessionEndpoint, "")
        XCTAssertEqual(openId.revocationEndpoint, "")
        XCTAssertNil(openId.deviceAuthorizationEndpoint)
        XCTAssertEqual(config.discoveryEndpoint, "")
    }

    func testCreateOidcDeviceClient_openIdWithoutDiscoveryEndpoint_seedsDeviceAuthorizationEndpoint() throws {
        var json = openIdOnlyJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = [
            "tokenEndpoint": "https://example.com/token",
            "deviceAuthorizationEndpoint": "https://example.com/device/code"
        ] as [String: Any]
        json["oidc"] = oidc

        let config = try parseOidcConfig(json)
        let openId = try XCTUnwrap(config.openId)
        XCTAssertEqual(openId.tokenEndpoint, "https://example.com/token")
        XCTAssertEqual(openId.deviceAuthorizationEndpoint, "https://example.com/device/code")
    }

    func testCreateOidcDeviceClient_failure_openIdWithoutTokenEndpoint() {
        var json = openIdOnlyJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = ["authorizationEndpoint": "https://example.com/authorize"] as [String: Any]
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.openId.tokenEndpoint), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.openId.tokenEndpoint")
    }

    func testCreateOidcDeviceClient_failure_blankDiscoveryEndpointWithoutOpenId() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["discoveryEndpoint"] = ""
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    func testCreateOidcDeviceClient_discoveryEndpointAndOpenId_discoveryOwnsDocument() throws {
        // fullJson carries both a discoveryEndpoint and an openId sub-object: discovery still runs and
        // the sub-object becomes an override, so no document is seeded at parse time.
        let config = try parseOidcConfig(fullJson)
        XCTAssertNil(config.openId, "Discovery should still own the document when both are supplied")
        XCTAssertNotNil(config.openIdOverride, "openId sub-object should become an openIdOverride")
        XCTAssertEqual(config.discoveryEndpoint, "https://example.com/.well-known/openid-configuration")
    }

    func testCreateOidcDeviceClient_signOutRedirectUri_silentlyIgnored() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["signOutRedirectUri"] = "myapp://logout"
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("signOutRedirectUri should be silently ignored, got: \(error)")
        }
    }

    func testCreateOidcDeviceClient_failure_additionalParametersNonStringValue() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["additionalParameters"] = ["key": 123]
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType for additionalParameters, got: \(result)"); return
        }
        XCTAssertTrue(field.hasPrefix("oidc.additionalParameters"))
    }

    // MARK: - par

    func testCreateOidcDeviceClient_par_true_accepted() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = true
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success with par=true, got: \(error)")
        }
    }

    func testCreateOidcDeviceClient_failure_par_wrongType() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = "yes"
        json["oidc"] = oidc

        let result = OidcDeviceClient.createOidcDeviceClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.par), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.par")
    }
}
