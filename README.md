[![Build Status](https://github.com/ForgeRock/unified-sdk-ios/actions/workflows/ci.yaml/badge.svg)](https://github.com/ForgeRock/unified-sdk-ios/actions/workflows/ci.yaml)

[![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)](https://github.com/ForgeRock/ping-ios-sdk)

The Ping Orchestration SDK for iOS is designed for creating mobile native apps that seamlessly integrate with the PingAM, Ping AIC, and PingOne platforms.
It offers a range of APIs for user authentication, user device management, and accessing resources secured by PingOne.

> [!NOTE]
> If you are migrating from the ForgeRock iOS SDK, refer to [MIGRATION.md](./MIGRATION.md).

# Documentation

- **Quick Starts** - Find specific setup instructions in the quick start guide for each SDK module.
  Begin with
  the [DaVinci](./Davinci/README.md)
  or [Journey](./Journey/README.md)
  guide, based on your chosen orchestration platform.
- **Sample Apps** - Visit our [sample apps](https://github.com/ForgeRock/sdk-sample-apps) repository
  on GitHub for examples showcasing various use cases.
- **Official Docs** - Refer to our
  main [documentation site](https://developer.pingidentity.com/orchsdks/index.html) for
  comprehensive information on the SDKs.

# Modules

    ping
    ├── Foundation                            # Foundation modules
    │   ├── PingLogger                        # Provides a logging interface and common loggers.
    │   └── PingStorage                       # Provides a secure storage interface.
    ├── Core                                  # Core SDK modules
    │   ├── PingNetwork                       # Network layer (HTTP client).
    │   ├── PingCommons                       # Provides common MFA capabilities such as OTP, Push, and WebAuthn.
    │   ├── PingBrowser                       # Provides in-app browser support for authentication flows.
    │   └── PingOrchestrate                   # Core authentication orchestration framework.
    ├── Plugins                               # Plugin contracts for orchestration
    │   ├── PingDavinciPlugin                 # Plugin contract for DaVinci integration.
    │   └── PingJourneyPlugin                 # Plugin contract for Journey integration.
    ├── Authentication                        # Authentication flow implementations
    │   ├── PingOidc                          # Provides OIDC login with integrated browser support.
    │   ├── PingDavinci                       # Orchestrates authentication flows with PingOne DaVinci.
    │   └── PingJourney                       # Orchestrates authentication flows with PingOne AIC Journeys.
    ├── Device                                # Device information and integrity
    │   ├── PingDeviceId                      # Provides a secure method for generating and managing unique device identifiers.
    │   ├── PingDeviceProfile                 # Provides a framework for collecting and managing device information.
    │   ├── PingDeviceClient                  # Device client information.
    │   └── PingTamperDetector                # Provides utilities for analyzing device integrity.
    ├── External Identity Providers           # Native social login integration
    │   ├── PingExternalIdP                   # Enables authentication through various external Identity Providers (IDPs).
    │   ├── PingExternalIdPApple              # Provides Sign in with Apple integration.
    │   ├── PingExternalIdPGoogle             # Provides Google Sign-In integration.
    │   └── PingExternalIdPFacebook           # Provides Facebook Sign-In integration. 
    ├── Security & Protection                 # Advanced security features
    │   ├── PingProtect                       # Provides advanced security integration with PingOne Protect.
    │   ├── PingReCaptchaEnterprise           # reCAPTCHA Enterprise integration.
    │   ├── PingFido                          # Provides FIDO2 / WebAuthn authentication support.
    │   └── PingRecognize                     # PingOne Recognize biometric authentication (enrollment and authentication).
    ├── MFA                                   # Multi-Factor Authentication
    │   ├── PingOath                          # Provides OATH-based one-time password functionality.
    │   └── PingPush                          # Push notification authentication.
    ├── Utilities                             # Helper modules
    │   └── PingBinding                       # Device binding (biometric / PIN / none).
    └── samples                               # Sample applications
        └── PingExample                       # Sample app demonstrating SDK usage

> [!NOTE]
> The `PingRecognize` module depends on the **Keyless SDK**, distributed through the private
> Cloudsmith registry (`keyless` scope). It is therefore not built by the default
> `Ping.xcworkspace`: open `SampleApps/PingWithRecognize.xcworkspace` and build the
> `PingExampleWithRecognize` scheme to try Recognize in the sample app. See
> [Recognize/README.md](./Recognize/README.md) for the registry setup.

# Support

If you encounter any issues, be sure to check our **[Troubleshooting](https://docs.pingidentity.com/sdks/latest/sdks/troubleshooting.html)** pages.

Support tickets can be raised whenever you need our assistance; here are some examples of when it is appropriate to open a ticket (but not limited to):

* Suspected bugs or problems with Ping Identity software.
* Requests for assistance - please look at the **[Documentation](https://docs.pingidentity.com/sdks)** and **[Knowledge Base](https://support.pingidentity.com/s/knowledge-base)** first.

You can raise a ticket using the **[Ping Identity Support Portal](https://support.pingidentity.com/s/)** that provides one stop access to support services.

The support portal shows all currently open support tickets and allows you to raise a new one by clicking **New Ticket**.

# Contributing

If you would like to contribute to this project, please see
the [contributions guide](./CONTRIBUTING.md).

# Disclaimer

> **This code is provided by Ping Identity Corporation ("Ping") on an "as is" basis, without warranty of any kind, to the fullest extent permitted by law.
> Ping Identity Corporation does not represent or warrant or make any guarantee regarding the use of this code or the accuracy, timeliness or completeness of any data or information relating to this code, and Ping Identity Corporation hereby disclaims all warranties whether express, or implied or statutory, including without limitation the implied warranties of merchantability, fitness for a particular purpose, and any warranty of non-infringement.
> Ping Identity Corporation shall not have any liability arising out of or related to any use, implementation or configuration of this code, including but not limited to use for any commercial purpose.
> Any action or suit relating to the use of the code may be brought only in the courts of a jurisdiction wherein Ping Identity Corporation resides or in which Ping Identity Corporation conducts its primary business, and under the laws of that jurisdiction excluding its conflict-of-law provisions.**


# License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details

© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved