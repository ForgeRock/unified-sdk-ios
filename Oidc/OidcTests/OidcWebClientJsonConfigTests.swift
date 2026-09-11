//
//  OidcWebClientJsonConfigTests.swift
//  OidcTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOidc
@testable import PingLogger

final class OidcWebClientJsonConfigTests: XCTestCase, @unchecked Sendable {

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
            "timeout": 20000,
            "log": "DEBUG",
            "oidc": [
                "clientId": "my-client",
                "discoveryEndpoint": "https://example.com/.well-known/openid-configuration",
                "scopes": ["openid", "profile", "email"],
                "redirectUri": "myapp://callback",
                "signOutRedirectUri": "myapp://logout",
                "refreshThreshold": 30,
                "acrValues": "Level3",
                "additionalParameters": ["custom": "value"]
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

    /// Parses the `oidc` sub-dictionary through the same entry point the factory uses, so the
    /// resulting `OidcClientConfig` can be inspected (the workflow exposes only its `WorkflowConfig`).
    private func parseOidcConfig(_ json: [String: Any]) throws -> OidcClientConfig {
        let oidc = json["oidc"] as! [String: Any]
        return try OidcClientConfig.from(oidcJson: oidc, logger: LogManager.none)
    }

    // MARK: - Success cases

    func testCreateOidcWebClient_success_minimalRequiredFields() {
        let result = OidcWebClient.createOidcWebClient(json: minimalJson)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success, got: \(error)")
        }
    }

    func testCreateOidcWebClient_success_allFields() {
        let result = OidcWebClient.createOidcWebClient(json: fullJson)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success, got: \(error)")
        }
    }

    func testCreateOidcWebClient_unknownFieldsSilentlyIgnored() {
        var json = minimalJson
        json["unknownField"] = "ignored"
        json["serverUrl"] = "https://example.com/am"

        let result = OidcWebClient.createOidcWebClient(json: json)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Unknown fields should be silently ignored, got: \(error)")
        }
    }

    // MARK: - timeout

    func testCreateOidcWebClient_timeoutConversion() {
        var json = minimalJson
        json["timeout"] = 20000

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(client.config.timeout, 20.0, accuracy: 0.001)
    }

    func testCreateOidcWebClient_timeoutDefault() {
        let result = OidcWebClient.createOidcWebClient(json: minimalJson)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(client.config.timeout, 15.0, accuracy: 0.001)
    }

    func testCreateOidcWebClient_failure_timeoutWrongType() {
        var json = minimalJson
        json["timeout"] = "20000"

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(timeout), got: \(result)"); return
        }
        XCTAssertEqual(field, "timeout")
    }

    // MARK: - log

    func testCreateOidcWebClient_logMapping_debug() {
        var json = minimalJson
        json["log"] = "DEBUG"

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(client.config.logger is StandardLogger)
    }

    func testCreateOidcWebClient_logMapping_warn() {
        var json = minimalJson
        json["log"] = "WARN"

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(client.config.logger is WarningLogger)
    }

    func testCreateOidcWebClient_logWrongType_softFault_succeeds() {
        var json = minimalJson
        json["log"] = 1

        let result = OidcWebClient.createOidcWebClient(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success when log has wrong type (soft fault), got: \(error)")
        }
    }

    // MARK: - oidc (required)

    func testCreateOidcWebClient_failure_missingOidc() {
        var json = minimalJson
        json.removeValue(forKey: "oidc")

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc")
    }

    func testCreateOidcWebClient_failure_oidcWrongType() {
        var json = minimalJson
        json["oidc"] = "not-an-object"

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc")
    }

    func testCreateOidcWebClient_failure_missingClientId() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "clientId")
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.clientId), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.clientId")
    }

    func testCreateOidcWebClient_failure_missingDiscoveryEndpoint() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "discoveryEndpoint")
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    func testCreateOidcWebClient_failure_missingScopes() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "scopes")
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.scopes), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    func testCreateOidcWebClient_failure_missingRedirectUri() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "redirectUri")
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.redirectUri), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.redirectUri")
    }

    func testCreateOidcWebClient_failure_scopesNotStringArray() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["scopes"] = [1, 2, 3]
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.scopes), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    func testCreateOidcWebClient_failure_additionalParametersNonStringValue() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["additionalParameters"] = ["key": 123]
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType for additionalParameters, got: \(result)"); return
        }
        XCTAssertTrue(field.hasPrefix("oidc.additionalParameters"))
    }

    // MARK: - openId as a replacement for the discovery document

    func testCreateOidcWebClient_openIdWithoutDiscoveryEndpoint_succeeds() throws {
        let result = OidcWebClient.createOidcWebClient(json: openIdOnlyJson)
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
        XCTAssertNil(openId.pushedAuthorizationRequestEndpoint)
        XCTAssertEqual(config.discoveryEndpoint, "")
    }

    func testCreateOidcWebClient_failure_openIdWithoutTokenEndpoint() {
        var json = openIdOnlyJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = ["authorizationEndpoint": "https://example.com/authorize"] as [String: Any]
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.openId.tokenEndpoint), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.openId.tokenEndpoint")
    }

    func testCreateOidcWebClient_failure_blankDiscoveryEndpointWithoutOpenId() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["discoveryEndpoint"] = ""
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    func testCreateOidcWebClient_discoveryEndpointAndOpenId_discoveryOwnsDocument() throws {
        // Both supplied: discovery still runs and the sub-object becomes an override, so no document
        // is seeded at parse time.
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = ["tokenEndpoint": "https://example.com/token"] as [String: Any]
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success with both discoveryEndpoint and openId, got: \(error)")
        }

        let config = try parseOidcConfig(json)
        XCTAssertNil(config.openId, "Discovery should still own the document when both are supplied")
        XCTAssertNotNil(config.openIdOverride, "openId sub-object should become an openIdOverride")
        XCTAssertEqual(config.discoveryEndpoint, "https://example.com/.well-known/openid-configuration")
    }

    // MARK: - par

    func testCreateOidcWebClient_par_true_accepted() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = true
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success with par=true, got: \(error)")
        }
    }

    func testCreateOidcWebClient_failure_par_wrongType() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = "yes"
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.par), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.par")
    }
}
