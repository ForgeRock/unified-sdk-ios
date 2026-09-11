[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# PingBrowser

Ping Browser is a library that allows you to instantiate and use an in-app browser for performing OIDC flows. 
This library act as a plugin to the `ExternalIdp` module,
and it provides the necessary configuration to launch the browser to authenticate with the External IDP.

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

Then add the `PingBrowser` product to your target's dependencies.

#### CocoaPods

```ruby
pod 'PingBrowser', '~> <version>'
```

### Import the Module

```swift
import PingBrowser
```

## Usage

The `PingBrowser` is used internally in the `External_idp` module. You can use the `PingBrowser` in standalone mode by calling the following:
```swift
await BrowserLauncher.currentBrowser?.launch(url: request.urlRequest.url!, customParams: nil, browserType: .authSession, browserMode: .login, callbackURLScheme: callbackURLScheme)
```


### BrowserLauncher configuration

The `BrowserLauncher` has the following public methods:
1. `reset()`
2. `launch(url: URL, customParams: [String: String]? = nil,
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String, logger: Logger = LogManager.logger) async throws -> URL`
3. `launch(url: URL, customParams: [String: String]? = nil,
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String, redirectUri: String?, logger: Logger = LogManager.logger) async throws -> URL`

The second overload additionally accepts the full `redirectUri`, which `.authSession`/`.ephemeralAuthSession` use to decide whether an https redirect can be intercepted via the OS-brokered `ASWebAuthenticationSession.Callback.https` API (see below). It has a default implementation on `BrowserLauncherProtocol` that forwards to the first overload with `redirectUri: nil`, so existing conformers keep compiling unchanged.

The `BrowserLauncher` supports the following types of `BrowserMode`:
1. `login` / `logout` — present the browser UI and wait for a `callbackURLScheme` match before `launch()` resolves (the behavior described throughout this README).
2. `custom` — present-only mode: `launch()` resolves as soon as the browser UI is presented, without ever waiting for a callback. See "Present-only mode" below.

The `BrowserLauncher` supports the following types of `BrowserType`:
1. `authSession` <-- Default
2. `sfViewController`
3. `nativeBrowserApp`
4. `ephemeralAuthSession`

All four `BrowserType` values are implemented:
- `authSession` and `ephemeralAuthSession` use `ASWebAuthenticationSession`.
- `sfViewController` uses `SFSafariViewController` and completes the redirect by observing `OpenURLMonitor.shared.urlPublisher` for a URL whose scheme matches the callback.
- `nativeBrowserApp` opens the URL via `UIApplication.open` and completes the redirect the same way, through `OpenURLMonitor`.

### Present-only mode (`browserMode: .custom`)

Some use cases need the browser to stay open indefinitely with no return-to-app callback ever expected — for example, a session-handoff / in-app-SSO pattern: the app opens an in-app browser on a URL that redirects to a *second webapp* and sets a session cookie there, and the browser is meant to just stay open showing that page, with no redirect back to the native app. Passing `browserMode: .login` (the default) for this use case would leave `launch()` suspended forever, since it always waits for a `callbackURLScheme` match.

Passing `browserMode: .custom` instead makes `launch()` resolve as soon as the browser UI has been successfully presented, returning the presented URL rather than a callback URL:

```swift
let presentedUrl = try await BrowserLauncher.currentBrowser.launch(
    url: handoffUrl,
    customParams: nil,
    browserType: .sfViewController,
    browserMode: .custom,
    callbackURLScheme: "unused" // required by the method signature, but ignored in this mode
)
// `launch()` has already returned — the browser is still on screen, showing `handoffUrl`
// (and wherever it redirects to next).
```

Per-`BrowserType` behavior in present-only mode:
- **`.sfViewController`** — the UI stays presented after `launch()` returns, and `callbackURLScheme` really is inert: no `OpenURLMonitor` subscription is ever installed for a present-only `.sfViewController` launch, so no incoming URL of any scheme can affect it. `isInProgress` stays `true` for as long as it's shown — there is no timeout or auto-dismiss — until the user dismisses it or the caller explicitly calls `reset()`.
- **`.authSession` / `.ephemeralAuthSession`** — the UI also stays presented after `launch()` returns, and `isInProgress` stays `true` the same way, **but `callbackURLScheme` (or the `redirectUri`-derived https callback) stays live at the OS level**, unlike `.sfViewController`. If the handed-off page's navigation ever produces a URL matching that scheme/host+path, `ASWebAuthenticationSession` will still intercept it and complete the session on its own, silently dismissing the sheet — there is no way to opt out of this while using `ASWebAuthenticationSession`. For a page that's truly guaranteed never to redirect back, this is usually harmless; if there's any chance it could, either pass a scheme/redirect URI that page's navigation cannot legitimately produce, or prefer `.sfViewController`.
- **`.nativeBrowserApp`** — resolves and returns to `isInProgress == false` immediately, since control has already left your app entirely for Safari; there's no in-app element for `BrowserLauncher` to keep "open."

Note that `ASWebAuthenticationSession` always shows its own OS-provided Cancel/Done chrome and this cannot be hidden, so `.sfViewController` is usually the better fit when the handoff page needs to look chromeless.

Because `isInProgress` stays `true` for the entire time a present-only `.sfViewController`/`.authSession`/`.ephemeralAuthSession` sheet is shown, any *other* call to `launch()` — for an unrelated purpose, e.g. a background token refresh — will throw `BrowserError.externalUserAgentAuthenticationInProgress` until that sheet is dismissed or `reset()` is called; `BrowserLauncher` only ever drives one browser UI at a time, regardless of mode.

### Redirect URI schemes: custom scheme vs. https (Universal Link)

The redirect URI you register with your identity provider can use either a custom URL scheme (e.g. `myapp://callback`) or an `https` Universal Link (e.g. `https://example.com/callback`). How that redirect is delivered back to the app depends on the `BrowserType`:

- **`sfViewController` / `nativeBrowserApp`** — both custom-scheme and `https` redirects work today, on every OS version this SDK supports (iOS 16.0+/macOS 13+). These browser types rely on `OpenURLMonitor`, which your app must feed by forwarding every incoming URL — including Universal Links — to `OpenURLMonitor.shared.handleOpenURL(url)` from `onOpenURL` (SwiftUI) or `application(_:continue:restorationHandler:)` (UIKit). See the sample app's `ContentView.swift`/`onOpenURL` wiring for the reference pattern. Without this forwarding, neither redirect scheme completes for these browser types. For `https` Universal Link redirects to be routed to your app by the OS, your app must also declare an `applinks:<host>` associated-domain entitlement and serve a matching `applinks` entry in your `apple-app-site-association` file; `OpenURLMonitor` handles delivery once the OS routes the callback, but it cannot compensate for a missing association.
- **`authSession` / `ephemeralAuthSession`** — custom-scheme redirects are unchanged and always supported (`ASWebAuthenticationSession(url:callbackURLScheme:)`). An `https` redirect is only intercepted by the sealed `ASWebAuthenticationSession` on **iOS 17.4+ / macOS 14.4+** (unsupported on macOS 13.0–14.3), using the OS-brokered `ASWebAuthenticationSession(url:callback: .https(host:path:))` initializer — the auth code never leaves the session via `onOpenURL`, preserving the security posture described below. On iOS 16.0–17.3 / macOS 13.0–14.3 (or if the https redirect URI has no derivable host), `launch` fails fast with a `BrowserError` (`.httpsCallbackUnsupportedOS` or `.invalidHTTPSRedirectConfiguration`) instead of hanging; use `.sfViewController`/`.nativeBrowserApp` (with `applinks` association and `OpenURLMonitor` forwarding) as a fallback on those OS versions. `authSession`/`ephemeralAuthSession` are never wired to `OpenURLMonitor`.

#### `webcredentials` associated-domain requirements (https + `authSession`/`ephemeralAuthSession`, iOS 17.4+/macOS 14.4+)

For the OS-brokered `Callback.https` interception to work, your app must be associated with the redirect's domain via the **`webcredentials`** service — not `applinks` and not `webauthenticationsession` (neither is correct for this API; `applinks` is the Universal Links service and using it here would reopen the security issue this mechanism avoids):

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

If you cannot meet these requirements, or need to support iOS versions below 17.4, use a custom-scheme redirect URI, or switch to `.sfViewController`/`.nativeBrowserApp` (with `OpenURLMonitor` forwarding, as described above).

### Security note: why `authSession`/`ephemeralAuthSession` never use `OpenURLMonitor`

Routing an OAuth2/OIDC authorization-code redirect through app-level `onOpenURL` (rather than keeping it sealed inside `ASWebAuthenticationSession`) lets another app on the device capture the code if the identity provider silently completes the redirect from an existing SSO session, bypassing the "fresh user interaction" guarantee `ASWebAuthenticationSession` provides. For this reason `authSession`/`ephemeralAuthSession` only ever resolve via their own completion handler (legacy `callbackURLScheme:` or `Callback.https`), never via `OpenURLMonitor`.

## License

This software may be modified and distributed under the terms of the MIT license. See the LICENSE file for details.

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved.
