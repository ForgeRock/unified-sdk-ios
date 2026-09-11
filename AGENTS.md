# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Cursor, GitHub Copilot, Gemini, etc.) when working with code in this repository. It follows the open AGENTS.md convention.

> **Note:** CLAUDE.md in this repository is a one-line redirect to AGENTS.md. Edit AGENTS.md only.
>
> **Plugin users:** Developers using the Ping SDK Agents plugin (ping-sdk-agents) receive additional implementation-level guidance via ios-architect, ios-engineer, ios-code-reviewer, and related agents. AGENTS.md is the repo-level foundation that both plugin users and bare-agent users share — it is complete enough to stand alone without the plugin.

## Overview

This is the Ping Orchestration SDK for iOS — a modular Swift Package Manager-based SDK integrating with PingAM, Ping AIC (DaVinci), and PingOne platforms. It targets iOS 16.0+ and macOS 13.0+, uses Swift 6.0+, and supports both SPM and CocoaPods distribution.

## Platform & Toolchain

- **iOS:** 16.0+
- **macOS:** 13.0+
- **Swift:** 6.0 (strict concurrency mode; `// swift-tools-version: 6.0` in Package.swift)
- **Distribution:** Swift Package Manager AND CocoaPods. Every module has a matching `Ping<Module>.podspec` at the repo root that must stay in sync with `Package.swift`. Both distribution paths are equally supported — changes to one must be reflected in the other.
- **Xcode:** Latest stable. The CI-pinned version is defined in `.github/workflows/build-and-test.yaml`.

## External Dependencies

All four of the following dependencies are conditionally linked with `.when(platforms: [.iOS])` in `Package.swift`. Code that uses their symbols must be guarded with `#if canImport(...)`.

| Dependency | Purpose | Repository |
|---|---|---|
| PingOne Signals SDK | Device protection and risk assessment | `pingidentity/pingone-signals-sdk-ios` |
| Google Sign-In iOS SDK | Google identity provider integration | `google/GoogleSignIn-iOS` |
| Facebook iOS SDK | Facebook identity provider integration | `facebook/facebook-ios-sdk` |
| ReCaptcha Enterprise | CAPTCHA-based bot protection | `GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk` |

## Build and Test Commands

```bash
# Build with SPM
swift build

# Run all unit tests
xcodebuild test \
  -workspace SampleApps/Ping.xcworkspace \
  -scheme PingTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -enableCodeCoverage YES

# Run tests for a specific module (replace <ModuleTests> with e.g. DavinciTests, OidcTests, OathTests)
xcodebuild test \
  -workspace SampleApps/Ping.xcworkspace \
  -scheme PingTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:<ModuleTests>
```

Test targets are named `<ModuleName>Tests` (e.g. `OrchestrateTests`, `DavinciTests`, `JourneyTests`, `OidcTests`, `OathTests`, `PushTests`).

## CI/CD

The project uses GitHub Actions with the following workflows under `.github/workflows/`:

| Workflow | Purpose |
|---|---|
| `ci.yaml` | Main pipeline — orchestrates build, unit tests, and BrowserStack E2E testing |
| `build-and-test.yaml` | Unit tests on macOS-26 with configurable Xcode versions |
| `browserstack-*.yaml` | Device farm testing on real iOS devices (BrowserStack) |
| `mend-cli-scan.yaml` | Security scanning (Mend CLI) |

**Test organisation:**
- Each module has its own `<ModuleName>Tests/` directory (e.g. `Davinci/DavinciTests/`, `Oidc/OidcTests/`).
- Integration tests live in subdirectories named `Integration Tests`.
- End-to-end tests use the `E2E` suffix.
- The main test host scheme is `PingTestHost` in `SampleApps/Ping.xcworkspace`.

## Architecture

### Core Abstraction: `PingOrchestrate`

`PingOrchestrate` is the backbone of the SDK. A `Workflow` object drives all authentication flows:
- `Workflow.createWorkflow { config in ... }` bootstraps a workflow
- Modules register hooks on the workflow via a `Setup<ModuleConfig>` object passed into each module's `setup` closure
- Hook types: `initialize`, `start`, `next`, `response`, `node`, `success`, `signOff`, `transform`
- The `transform` hook converts raw HTTP responses into `Node` objects
- `Node` is the common protocol: concrete types are `ContinueNode`, `SuccessNode`, `FailureNode`, `ErrorNode`, `EmptyNode`
- `FlowContext` carries per-flow state via `SharedContext` (a key-value store shared across modules in a single flow)

### Module Pattern

Every feature is packaged as a `Module<ModuleConfig>`:
```swift
Module.of { MyConfig() } setup: { setup in
    setup.start { ctx, request in ... }
    setup.transform { ctx, response in ... }
}
```
Modules are registered during `Workflow.createWorkflow` and do not communicate directly — they interact only through `SharedContext` and the hook pipeline.

### Plugin Decoupling (`PingDavinciPlugin`, `PingJourneyPlugin`)

These lightweight protocol layers (`Collector`, `ContinueNode`, `Submittable`, `DaVinciAware`) decouple feature modules (FIDO, Protect, ExternalIdP, ReCaptcha) from having a hard dependency on `PingDavinci` or `PingJourney`. Feature modules depend only on the plugin target; they work in both DaVinci and Journey contexts.

### Authentication Flows

| Module | Purpose |
|---|---|
| `PingOidc` | OIDC/OAuth 2.0 client, PKCE, token management, device auth grant |
| `PingDavinci` | DaVinci flow engine — transforms responses into `ContinueNode` containing `Collectors` |
| `PingJourney` | PingAM Tree/Journey engine — transforms responses into `ContinueNode` containing `Callbacks` |

**DaVinci Collectors** (`Davinci/Davinci/collector/`): `TextCollector`, `PasswordCollector`, `SingleSelectCollector`, `MultiSelectCollector`, `FlowCollector`, `SubmitCollector`, `DeviceRegistrationCollector`, `DeviceAuthenticationCollector`, `PollingCollector`, etc.

**Journey Callbacks** (`Journey/Journey/Callbacks/`): `NameCallback`, `PasswordCallback`, `ChoiceCallback`, `ConfirmationCallback`, `ValidatedUsernameCallback`, `ValidatedPasswordCallback`, `KbaCreateCallback`, etc.

### Dependency Hierarchy

```
PingLogger, PingStorage ← foundation (no deps)
PingNetwork ← PingLogger
PingCommons ← PingLogger
PingBrowser ← PingLogger
PingOrchestrate ← PingStorage, PingNetwork
PingDavinciPlugin, PingJourneyPlugin ← PingOrchestrate
PingOidc ← PingOrchestrate, PingBrowser, PingCommons
PingDavinci ← PingOidc, PingDavinciPlugin
PingJourney ← PingOidc, PingJourneyPlugin, PingDeviceProfile
PingReCaptchaEnterprise ← PingCommons, PingJourneyPlugin, ReCaptcha Enterprise (iOS only)
PingExternalIdP ← PingBrowser, PingDavinciPlugin, PingJourneyPlugin
PingExternalIdP{Apple,Google,Facebook} ← PingExternalIdP (+ vendor SDK on iOS only)
PingProtect ← PingDavinciPlugin, PingJourneyPlugin, PingOneSignals (iOS only)
PingFido ← PingLogger, PingCommons, PingDavinciPlugin, PingJourneyPlugin
PingBinding ← PingCommons, PingDeviceId, PingJourneyPlugin
PingOath ← PingTamperDetector
PingPush ← PingNetwork, PingTamperDetector
PingAuthMigration ← PingOath, PingPush
PingRecognize ← PingJourneyPlugin, KeylessSDK (iOS only)
PingDeviceClient ← PingCommons, PingNetwork
```

### Storage Layer

`PingStorage` provides `StorageDelegate` (protocol) with three built-in backends: `KeychainStorage`, `MemoryStorage`, `EncryptedKeychainStorage` (Keychain + SecuredKey encryption). Custom backends can be plugged in by conforming to `StorageDelegate`.

### Network Layer

`PingNetwork` provides a protocol-based HTTP client (`HttpClientProtocol`) with async/await. Interceptors are composable via `Interceptors/`. The `HttpClient` is instantiated through `HttpClientConfig` and shared via `Setup.httpClient`.

## Project Layout

Source lives at `<ModuleName>/<ModuleName>/` (e.g. `Davinci/Davinci/`). Tests are at `<ModuleName>/<ModuleName>Tests/`. Each module also ships a `.podspec` at the repo root and a `PrivacyInfo.xcprivacy` file.

The sample app workspace is `SampleApps/Ping.xcworkspace` with `PingTestHost` as the test scheme.

## Contributing

- Branch off `develop`; PRs target `develop`
- Commits must be signed (`git commit -S`)
- Commit format: `[feat|fix|docs|refactor|test]: short description`
- External IdP SDKs (Google, Facebook) and PingOneSignals are conditionally linked with `.when(platforms: [.iOS])` — guard new Apple-framework-only code with `#if canImport(...)` where needed
