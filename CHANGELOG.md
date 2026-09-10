## [UNRELEASED]
#### Updated
- Updated `RecaptchaEnterprise` dependency to 18.9.1 for Xcode 27 / iOS 27 compatibility [SDKS-5306]
- Split the Recognize sample into a dedicated `PingWithRecognize.xcworkspace` (requires the Cloudsmith `keyless` registry); the core `Ping.xcworkspace` no longer references Recognize or Keyless and builds without registry credentials [P1RECMOB-3476]

#### Added
- Added `ImageCollector` to support image display in DaVinci forms [SDKS-5143]
- Added `MetadataCollector` to support the DaVinci SDK Integrator connector's pause/resume model, allowing the app to invoke on-device SDKs and return a result or error before the flow continues [SDKS-5142]
- Added `trigger` and `isAutomatic` to the DaVinci FIDO collectors [SDKS-4552]
- Added Facebook Limited Login (OIDC ID-token flow) support in `PingExternalIdPFacebook`. Toggle via the new `facebookLimitedLoginEnabled` property on `IdpCollector` (DaVinci) or on `FacebookHandler` / `FacebookRequestHandler` directly; defaults to `false` (classic OAuth2). On the Journey path, provider names containing `fb-limited` automatically opt into Limited Login [SDKS-5160, SDKS-5161, SDKS-5162]
- Bumped `facebook-ios-sdk` to 18.1.0 [SDKS-5160]
- `oidc.discoveryEndpoint` in the unified JSON configuration is now required only when no `oidc.openId` sub-object is supplied; an `openId` block without `discoveryEndpoint` replaces the discovery document and requires `tokenEndpoint` [SDKS-5301]
- Added `OidcError.configurationError` to report a configuration that has neither a usable `discoveryEndpoint` nor a pre-supplied `openId` [SDKS-5301]

#### Fixed
- Fixed `QRCodeCollector` not preserving the complete QR code data URI in `content` [SDKS-5299]
- Fixed `OidcWebClient` `.authSession` and `.ephemeralAuthSession` not completing for Universal Link (https) redirect URIs [SDKS-5239]
- Fixed `OidcWebClient.authorize()` collapsing `FailureNode.cause` to `.unknown`, losing typed browser-cancellation and unsupported-OS error identity [SDKS-5295]
- Fixed FIDO registration/authentication not launching automatically when the DaVinci form's `trigger` property is not `BUTTON` [SDKS-4552]
- Restored `OidcClientConfig.openId` as a publicly settable property and made `oidcInitialize()` skip OpenID discovery when it is pre-supplied, restoring the 2.0.0 no-discovery configuration path [SDKS-5301]
- Fixed 5xx AM responses with a parseable error body being misclassified as `FailureNode` instead of `ErrorNode`, diverging from Android [SDKS-5358]
- Fixed `Journey.start(backchannelUri:)` not rejecting whitespace-only `authIndexType`/`authIndexValue`, diverging from Android [SDKS-5359]
- Fixed the async `OidcClient.generateAuthorizeUrl(customParams:) async throws -> URL` silently falling back to the standard (non-PAR) flow when called before `OidcClientConfig.oidcInitialize()`, which could emit `additionalParameters` onto the returned URL instead of the PAR POST body; the synchronous overload never supported PAR and is unaffected [SDKS-5403]

#### Changed
- `OidcError` gained a `configurationError` case — exhaustive `switch` statements over `OidcError` need a new branch [SDKS-5301]
- A JSON configuration with a blank `oidc.discoveryEndpoint` and no `oidc.openId` sub-object now fails at parse time instead of at first use [SDKS-5301]
- `OidcClientConfig.oidcInitialize()` cancellation is now isolated per caller: cancelling one caller's own task still returns promptly with `CancellationError`, but no longer cancels the shared discovery/`openIdOverride` operation for any other caller currently sharing it [SDKS-5301]

## [2.1.0]
#### Added
- Added OAuth 2.0 Device Authorization Grant (RFC 8628) support [SDKS-4785]
- Added Pushed Authorization Request (PAR) support for OIDC [SDKS-4235]
- Added unified JSON configuration support [SDKS-5066]
- Added `PollingCollector` for DaVinci flows [SDKS-4682]
- Added `QrCodeCollector` for DaVinci flows [SDKS-4680]
- Added `SingleCheckboxCollector` for DaVinci forms [SDKS-4920]
- Added `ReadOnlyTextCollector` for DaVinci forms [SDKS-4928]
- Added `RichContent` and `RichContentReplacement` types with rich text and embedded link support to `LabelCollector` [SDKS-4245]
- Added phone number extension support in `PhoneNumberCollector` [SDKS-4668]
- Added `PushError.pushNumberChallengeError` to surface a distinct failure for Push Number Challenge responses [SDKS-5115]
- Added `preferImmediatelyAvailableCredentials` option to FIDO authentication to restrict the ceremony to locally-available credentials only [SDKS-5212]
- Added `PingRecognize` module for PingOne Recognize biometric authentication (enrollment and authentication) [P1RECMOB-3663]
- Added `AuthMigration` module for migrating existing sessions from the legacy ForgeRock SDK [SDKS-4773]
- Added Page Node description, header, and footer support [SDKS-4762]
- Added AM/AIC backchannel authentication support to the `PingJourney` module via `Journey.start(backchannelUri:configure:)` [SDKS-5156]

#### Fixed
- Fixed permanent authentication failure after iCloud device migration caused by Secure Enclave key mismatch [SDKS-5172]
- Fixed `PingFido` WebAuthn registration ignoring the configured `displayName` during passkey creation [SDKS-5211]
- Fixed `PasswordCollector` not handling nested password policies [SDKS-4695]
- Fixed PIN verification during device binding registration [SDKS-5015]
- Fixed `Protect` collector being triggered multiple times within a flow [SDKS-4769]
- Fixed browser close and reset logic [SDKS-4717]
- Fixed Device Binding authenticators incorrectly reporting as supported on simulator [SDKS-4836]
- Fixed `DeviceBindingConfig` device name defaulting to the user-assigned name instead of the device model [SDKS-4850]
- Fixed `DefaultDeviceIdentifier` to reuse the legacy device identifier when available [SDKS-4630]
- Fixed Swift build failures — platform bump and `canImport` guards [SDKS-4916]
- Fixed FIDO ceremony logs not routing through the workflow logger [SDKS-4924]

## [2.0.0]
#### Added
- Added new `PingJourney` module [SDKS-3918]
- Added new `PingNetwork` module [SDKS-4496]
- Added new `PingDeviceClient` module [SDKS-4491]
- Added new `PingDeviceId` module [SDKS-4122]
- Added new `PingDeviceProfile` module [SDKS-4128]
- Added new `PingTamperDetector` module [SDKS-4366]
- Added new `PingJourneyPlugin` and `PingDavinciPlugin` modules [SDKS-4492]
- Added new `PingCommons` module [SDKS-4104]
- Added new `PingOath` module [SDKS-4100]
- Added new `PingPush` module [SDKS-4105]
- Added new `PingFido` module [SDKS-4137]
- Added new `PingBinding` module [SDKS-4117]
- Added new `PingReCaptchaEnterprise` module [SDKS-4440]
- Added support for core callbacks in the `PingJourney` module [SDKS-4060]
- Added support for native social login for Facebook, Google and Apple for AIC [SDKS-3898]
- Added migration mechanism for existing device binding data from the Legacy SDK to the new SDK [SDKS-4495]

#### Fixes
- Updated `PingStorage` module to allow multiple DaVinci/Journey instances to have separate cookies, sessions, and token storage [SDKS-4588]

## [1.3.1]
#### Fixed
- Fixed an issue in the `PingProtect` module causing a crash on iOS 17+ due to an incorrect actor executor assumption [SDKS-4494] 
- Updated all targets to use the Swift 6 compiler [SDKS-4499]

## [1.3.0]
#### Added
- New `PingProtect` module [SDKS-4071]
- Support for the `Protect` collector and integration with DaVinci [SDKS-4073]
- New `PingOidc` login module with integrated browser support [SDKS-4149]

#### Updated
- Country code format for the `PhoneNumber` collector in DaVinci [SDKS-4199]
- Redesigned and improved PingExample app [SDKS-4104]

## [1.2.0]

#### Added
- Support for native social login with Apple, Google and Facebook [SDKS-3450]
- Support for PingOne Forms MFA OTP components `DEVICE_REGISTRATION`, `DEVICE_AUTHENTICATION`, and `PHONE_NUMBER` [SDKS-3563]
- Support for accessing the previous `ContinueNode` from `ErrorNode` [SDKS-3891]
- Support for accessing the `key` attribute of `LabelCollector` [SDKS-3956]
- New `PingExternalIdPApple` module [SDKS-3958]
- New `PingExternalIdPGoogle` module [SDKS-3958]
- New `PingExternalIdPFacebook` module [SDKS-3958]

#### Fixed
- Resolved an issue where cookies were incorrectly cleared from in-memory storage on requests containing a `Set-Cookie` header [SDKS-4189]

#### Changed
- Renamed `PingExternal-idp` module to `PingExternalIdP` [SDKS-3958]

## [1.1.0]

#### Added
- Support for PingOne Forms field types LABEL, CHECKBOX, DROPDOWN, COMBOBOX, RADIO, PASSWORD, PASSWORD_VERIFY, FLOWLINK [SDKS-3671, SDKS-3672]
- Support for validation of PingOne Forms fields [SDKS-3671, SDKS-3672]
- Handling default values for PingOne Forms fields [SDKS-3674]
- Interface for access of ErrorNode with validation error [SDKS-3675]
- Support for Social Login with Browser Redirect [SDKS-3720]
- Support for `Accept-Language` header [SDKS-3623]
- Swift 6 Support [SDKS-3728]
- New `PingBrowser` module [SDKS-3920]
- New `PingExternal-idp` module [SDKS-3920]

## [1.0.0]
- General Availability release of the Ping SDK for iOS

#### Added
- Added Logger initial version
- Added Storage initial version
- Added Oidc initial version
- Added Orchestrate initial version
- Added Davinci initial version
