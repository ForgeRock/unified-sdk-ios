[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingOidc

`PingOidc` module provides a generic OIDC client that can be used with PingOne and ForgeRock platforms.

The `PingOidc` module follows the [OIDC](https://openid.net/specs/openid-connect-core-1_0.html) specification and
provides a simple and easy-to-use API to interact with the OIDC server. It allows you to authenticate, retrieve the
access token, revoke the token, and sign out from the OIDC server.

## Getting Started

### Prerequisites

- iOS 16.0+
- Swift 6.0+
- Xcode 15+

### Installation

To integrate the module into your iOS project, add the following dependency to your `Package.swift` or `Podfile` file.

#### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "<version>")
]
```

Then add the `PingOidc` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingOidc', '~> <version>'
```

### Import the Module

```swift
import PingOidc
```

## Oidc Client Configuration

Basic Configuration, use `discoveryEndpoint` to lookup OIDC endpoints

```swift
// Create an OIDC client with the discovery endpoint, and other configurations
public let oidcLogin = OidcWebClient.createOidcWebClient { config in
    config.module(PingOidc.OidcModule.config) { oidcValue in
        oidcValue.clientId = "ClientID"
        oidcValue.scopes = ["openid", "email", "address", "profile", "phone"]
        oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
        oidcValue.discoveryEndpoint = "https://example.com/.well-known/openid-configuration"
    }
}

//Start the OIDC authentication flow
let state = try await oidcLogin.authorize { options in
    // Pass additional parameters
    options.additionalParameters = ["foo": "bar"]
}

// Handle the state
switch oidcLogin.state {
case .success( _ ):
    ...
case .failure(let error):
    ...
case .none:
    ...
}

// To retrieve the existing user
let oidcLoginUser = await oidcLogin.oidcLoginUser()

// To receive the access token
let token = await oidcLoginUser.token()

// Other methods
oidcLoginUser?.revoke()
oidcLoginUser?.logout()

// Setting the browser type and mode
public let oidcLogin = OidcWebClient.createOidcWebClient { config in
    // Set the browser mode(only the .login mode supported currently) and browser type.
    config.browserMode = .login
    config.browserType = .authSession
    config.module(PingOidc.OidcModule.config) { oidcValue in
        oidcValue.clientId = "ClientID"
        oidcValue.scopes = ["openid", "email", "address", "profile", "phone"]
        oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
        oidcValue.discoveryEndpoint = "https://example.com/.well-known/openid-configuration"
    }
}
```

By default, the SDK uses `KeychainStorage` (with `SecuredKeyEncryptor`) to store the token and `none` Logger is set,
however developers can override the storage and logger settings.

Basic Configuration with custom `storage` and `logger`

```swift
let config = OidcClientConfig()
config.logger = LogManager.standard //Log to console
config.storage = CustomStorage<Token>() //Use Custom Storage
//...

let ping = OidcClient(config: config)
```

### Configuring without discovery

If you already know your provider's endpoints — or your provider publishes no discovery document — set `openId` directly and omit `discoveryEndpoint`. No discovery request is made.

```swift
public let oidcLogin = OidcWebClient.createOidcWebClient { config in
    config.module(PingOidc.OidcModule.config) { oidcValue in
        oidcValue.clientId = "ClientID"
        oidcValue.scopes = ["openid", "email", "profile"]
        oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
        // No discoveryEndpoint — these endpoints are used as-is.
        oidcValue.openId = OpenIdConfiguration(
            authorizationEndpoint: "https://example.com/as/authorize",
            tokenEndpoint: "https://example.com/as/token",
            userinfoEndpoint: "https://example.com/as/userinfo",
            endSessionEndpoint: "https://example.com/as/signoff",
            revocationEndpoint: "https://example.com/as/revoke"
        )
    }
}
```

`authorizationEndpoint`, `tokenEndpoint`, `userinfoEndpoint`, `endSessionEndpoint` and `revocationEndpoint` are required by the initializer; `pingEndsessionEndpoint`, `pushedAuthorizationRequestEndpoint` and `deviceAuthorizationEndpoint` are optional and default to `nil`.

Set `openId` before handing the configuration to a client or workflow. If `openId` is left `nil`, the SDK discovers the document from `discoveryEndpoint` as usual. Supplying neither throws `OidcError.configurationError`.

`openIdOverride` still runs, and is applied exactly once, on top of whichever document is used — discovered or pre-supplied:

```swift
oidcValue.openId = OpenIdConfiguration(/* ... */)
oidcValue.openIdOverride = { openId in
    openId.deviceAuthorizationEndpoint = "https://example.com/device/code"
}
```

## Redirect URI and browser type

`redirectUri` can be a custom URL scheme (e.g. `org.forgerock.demo://oauth2redirect`) or an `https` Universal Link (e.g. `https://example.com/callback`). Which `browserType` you use determines how that redirect is delivered back to the app:

- **`.sfViewController` / `.nativeBrowserApp`** — both custom-scheme and `https` redirect URIs work today, on every OS version this SDK supports (iOS 16.0+). These browser types complete the redirect by observing `OpenURLMonitor.shared.urlPublisher`, which requires your app to forward every incoming URL — including Universal Links — to `OpenURLMonitor.shared.handleOpenURL(url)` from `onOpenURL` (SwiftUI) or `application(_:continue:restorationHandler:)` (UIKit). See the sample app's `ContentView.swift`/`onOpenURL` wiring for the reference pattern. Without this forwarding, the redirect never completes for these browser types. For `https` Universal Link redirects, your app must also declare an `applinks:<host>` associated-domain entitlement and serve a matching `applinks` entry in your `apple-app-site-association` file; `OpenURLMonitor` handles delivery once the OS routes the callback, but the OS association is required.
- **`.authSession` / `.ephemeralAuthSession`** (the default) — custom-scheme redirects are always supported. An `https` redirect is only intercepted by the sealed `ASWebAuthenticationSession` on **iOS 17.4+ / macOS 14.4+**, via the OS-brokered `Callback.https` API — this keeps the authorization code inside the session rather than routing it through `onOpenURL`. **On iOS 16.0–17.3 / macOS 13.0–14.3, an `https` `redirectUri` with `.authSession`/`.ephemeralAuthSession` throws `OidcError.authorizeError` wrapping `BrowserError.httpsCallbackUnsupportedOS`** instead of hanging. If the `https` redirect URI has no derivable host (on any OS version), it throws `OidcError.authorizeError` wrapping `BrowserError.invalidHTTPSRedirectConfiguration` instead. On those OS versions, use `.sfViewController` or `.nativeBrowserApp` (with `applinks` association and `OpenURLMonitor` forwarding) as a fallback.

If you need an `https` redirect URI and must support iOS 16.0-17.3, you have two options:

1. **Switch `browserType`** to `.sfViewController` or `.nativeBrowserApp` — these work on 16.0-17.3 today, provided your app forwards the Universal Link via `OpenURLMonitor.shared.handleOpenURL(url)` as described above:
   ```swift
   let oidcLogin = OidcWebClient.createOidcWebClient { config in
       config.browserType = .sfViewController
       config.module(PingOidc.OidcModule.config) { oidcValue in
           oidcValue.redirectUri = "https://example.com/callback"
           // ...
       }
   }
   ```
2. **Register a custom-scheme redirect URI** with your identity provider instead of an `https` one, and keep `.authSession`/`.ephemeralAuthSession`.

### `webcredentials` associated-domain requirements (https + `.authSession`/`.ephemeralAuthSession`, iOS 17.4+/macOS 14.4+)

To use an `https` redirect URI with `.authSession`/`.ephemeralAuthSession` on iOS 17.4+/macOS 14.4+, your app must declare a **`webcredentials`** association with the redirect's domain — not `applinks` and not `webauthenticationsession`:

1. Add the entitlement to your app target:
   ```xml
   <key>com.apple.developer.associated-domains</key>
   <array>
       <string>webcredentials:example.com</string>
   </array>
   ```
2. Serve `https://example.com/.well-known/apple-app-site-association` from the domain, with a `webcredentials` entry listing your app's Team ID + Bundle ID:
   ```json
   {
       "webcredentials": {
           "apps": ["ABCDE12345.com.example.myapp"]
       }
   }
   ```

See the [`PingBrowser` README](../Browser/README.md#webcredentials-associated-domain-requirements-https--authsessionephemeralauthsession-ios-174macos-144) for the full rationale, including why `.authSession`/`.ephemeralAuthSession` never route through `OpenURLMonitor`.

## Advanced OIDC Configuration

Configurable attributes can be found under the [OIDC Spec](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest)

```swift
let config = OidcClientConfig()
config.acrValues = "urn:acr:form"
config.loginHint = "test"
config.display = "test"
//...

let ping = OidcClient(config: config)
```

## Pushed Authorization Requests (PAR)

`PingOidc` supports [Pushed Authorization Requests (RFC 9126)](https://datatracker.ietf.org/doc/html/rfc9126). When PAR is enabled, authorization parameters are sent to the server via a POST request to the `pushed_authorization_request_endpoint` before the authorization redirect. The server returns a `request_uri` which is then used in the authorization URL instead of the full set of parameters.

To enable PAR, set the `par` property to `true` in the OIDC configuration:

```swift
let oidcLogin = OidcWebClient.createOidcWebClient { config in
    config.module(PingOidc.OidcModule.config) { oidcValue in
        oidcValue.clientId = "ClientID"
        oidcValue.scopes = ["openid", "email", "address", "profile", "phone"]
        oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
        oidcValue.discoveryEndpoint = "https://example.com/.well-known/openid-configuration"
        oidcValue.par = true // Enable Pushed Authorization Requests
    }
}
```

**Requirements:**
- The server's OpenID configuration (discovery document) must include a `pushed_authorization_request_endpoint`.
- If `par` is enabled but the discovery document does not include the PAR endpoint, the SDK falls back to the standard authorization flow automatically.

## Device Authorization Grant (RFC 8628)

`PingOidc` supports the [OAuth 2.0 Device Authorization Grant (RFC 8628)](https://datatracker.ietf.org/doc/html/rfc8628) for input-constrained devices (smart TVs, CLI tools) that can't directly open a browser. Use `OidcDeviceClient` to start a device flow, display the user code and verification URL, and poll for the access token.

```swift
let deviceClient = OidcDeviceClient.createOidcDeviceClient { config in
    config.clientId = "ClientID"
    config.scopes = ["openid", "profile", "email"]
    config.redirectUri = "org.forgerock.demo://oauth2redirect"
    config.discoveryEndpoint = "https://auth.example.com/.well-known/openid-configuration"
}

// Start the flow — returns an AsyncThrowingStream<DeviceFlowStatus, Error>
let stream = try await deviceClient.deviceAuthorization()

for try await status in stream {
    switch status {
    case .started(let response):
        // Display response.userCode and response.verificationUri (or response.verificationUriComplete)
        // to the user — for example as a QR code linking to verificationUriComplete.
        print("Visit \(response.verificationUri) and enter \(response.userCode)")
    case .polling(let pollCount, let pollInterval, let nextPollAt):
        // Optional: update UI with polling progress
        break
    case .success(let user):
        // Token has been saved to storage. `user` is an OidcUser ready to call .token() on.
        let token = await user.token()
    case .accessDenied:
        // The user denied the request.
        break
    case .expired:
        // The user code expired before the user authorized.
        break
    case .failure(let error):
        // Terminal error not covered by the RFC 8628 error codes.
        break
    }
}

// Optionally open the verification URL in SFSafariViewController on this device:
try await deviceClient.authorize(verificationUriComplete: response.verificationUriComplete ?? response.verificationUri)

// Retrieve the existing user (returns nil if no token has been saved):
let user = await deviceClient.user()

// Revoke the stored token:
await deviceClient.revoke()
```

**Requirements:**
- The server's OpenID configuration (discovery document) must include a `device_authorization_endpoint`.
- If the endpoint is missing, `deviceAuthorization()` throws `OidcError.unknown`.

The polling loop honors the server-supplied `interval` and increases it by 5 seconds on every `slow_down` response per RFC 8628. Network errors (`URLError`) trigger an exponential backoff (capped at 60 seconds) and the stream continues; the stream only finishes on `.success`, `.accessDenied`, `.expired`, or a non-recoverable error.

## Custom Agent

You can also provide a custom agent to launch the authorization request.
You can implement the `Agent` interface to create a custom agent.

```swift
protocol Agent<T> {
     associatedtype T
     
     func config() -> () -> T
     func endSession(oidcConfig: OidcConfig<T>, idToken: String) async throws -> Bool
     func authorize(oidcConfig: OidcConfig<T>) async throws -> AuthCode
}
```

Here is an example of creating a custom agent.

```swift
//Create a custom agent configuration
struct CustomAgentConfig {
    var config1 = "config1Value"
    var config2 = "config2Value"
}

class CustomAgent: Agent {
    func config() -> () -> CustomAgentConfig {
        return { CustomAgentConfig() }
    }
    
    func authorize(oidcConfig: Oidc.OidcConfig<T>) async throws -> Oidc.AuthCode {
        oidcConfig.config.config2 //Access the agent configuration
        oidcConfig.oidcClientConfig.openId?.endSessionEndpoint //Access the oidcClientConfig
        return AuthCode(code: "TestAgent", codeVerifier: "")
    }
    
    func endSession(oidcConfig: Oidc.OidcConfig<CustomAgentConfig>, idToken: String) async throws -> Bool {
        //Logout session with idToken
        oidcConfig.config.config1 //Access the agent configuration
        oidcConfig.oidcClientConfig.openId?.endSessionEndpoint //Access the oidcClientConfig
        return true
    }
}

let config = OidcClientConfig()
config.updateAgent(CustomAgent())
//...

let ping = OidcClient(config: config)

```

## Migration Guide

### Migrating to `OidcWebClient` (from 2.0.0)

The following classes and methods have been renamed for consistency starting from version 2.0.0:

| Old Name | New Name |
|----------|----------|
| `OidcWeb` | `OidcWebClient` |
| `OidcWebConfig` | `OidcWebClientConfig` |
| `createOidcWeb` | `createOidcWebClient` |

**Before:**
```swift
let oidcLogin = OidcWeb.createOidcWeb { config in
    // configuration
}
```

**After:**
```swift
let oidcLogin = OidcWebClient.createOidcWebClient { config in
    // configuration
}
```

## JSON Configuration

Both `OidcWebClient` and `OidcDeviceClient` can be initialised from a platform-neutral dictionary, enabling config-file-driven setup.

### OidcWebClient

```swift
let json: [String: Any] = [
    "timeout": 30000,          // milliseconds — optional, default 15 s
    "log": "DEBUG",            // optional
    "oidc": [
        "clientId": "your-client-id",
        "discoveryEndpoint": "https://auth.example.com/.well-known/openid-configuration",
        "redirectUri": "myapp://callback",
        "scopes": ["openid", "profile", "email"],
        // --- optional ---
        "par": true,
        "acrValues": "policy-id",
        "signOutRedirectUri": "myapp://logout"
    ] as [String: Any]
]

switch OidcWebClient.createOidcWebClient(json: json) {
case .success(let client):
    let result = try await client.authorize()
case .failure(let error):
    print("Configuration error: \(error.localizedDescription)")
}
```

### OidcDeviceClient

```swift
let json: [String: Any] = [
    "log": "WARN",             // optional
    "oidc": [
        "clientId": "your-client-id",
        "discoveryEndpoint": "https://auth.example.com/.well-known/openid-configuration",
        "redirectUri": "myapp://callback",
        "scopes": ["openid"],
        // override the device authorization endpoint if not in discovery
        "openId": [
            "deviceAuthorizationEndpoint": "https://auth.example.com/device/code"
        ] as [String: Any]
    ] as [String: Any]
]

switch OidcDeviceClient.createOidcDeviceClient(json: json) {
case .success(let client):
    let stream = try await client.deviceAuthorization()
case .failure(let error):
    print("Configuration error: \(error.localizedDescription)")
}
```

> **Note:** The top-level `timeout` key is not applied to `OidcDeviceClient` — the device flow HTTP client uses the framework default. Configure the device authorization endpoint via the `openId` override block if it is not advertised in the OIDC discovery document.

### Without a discovery endpoint

`oidc.discoveryEndpoint` is required *unless* an `oidc.openId` sub-object is supplied. A blank or whitespace-only `discoveryEndpoint` counts as absent.

When `openId` is supplied **without** `discoveryEndpoint`, it replaces the discovery document (no network call) and `oidc.openId.tokenEndpoint` becomes required. Any other non-optional endpoint you omit defaults to an empty string, so supply every endpoint your flow actually uses.

```swift
let json: [String: Any] = [
    "oidc": [
        "clientId": "your-client-id",
        "redirectUri": "myapp://callback",
        "scopes": ["openid", "profile"],
        // No discoveryEndpoint — this block *is* the OpenID configuration.
        "openId": [
            "authorizationEndpoint": "https://auth.example.com/as/authorize",
            "tokenEndpoint": "https://auth.example.com/as/token",   // required here
            "userinfoEndpoint": "https://auth.example.com/as/userinfo",
            "endSessionEndpoint": "https://auth.example.com/as/signoff",
            "revocationEndpoint": "https://auth.example.com/as/revoke"
        ] as [String: Any]
    ] as [String: Any]
]
```

When **both** are supplied, behaviour is unchanged: discovery runs and the `openId` block patches the discovered document — which is the idiom used in the `OidcDeviceClient` example above.

### Error handling

On invalid input both factories return `.failure(JsonConfigError)`:

| Error | Cause |
|-------|-------|
| `missingRequiredField(String)` | A required field is absent — e.g. `oidc.discoveryEndpoint` when no `oidc.openId` block is supplied, or `oidc.openId.tokenEndpoint` in the no-discovery form |
| `invalidType(field:expected:)` | A field has the wrong type |

At runtime, a configuration that ends up with neither a usable `discoveryEndpoint` nor a pre-supplied `openId` throws `OidcError.configurationError(message:)` rather than failing later with a vague error:

| Error | Cause |
|-------|-------|
| `OidcError.configurationError(message:)` | Neither `discoveryEndpoint` nor `openId` is set, `discoveryEndpoint` is blank or malformed, or no HTTP client is available |

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
