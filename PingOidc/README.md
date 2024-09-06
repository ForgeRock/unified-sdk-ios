<div>
  <picture>
     <img src="https://www.pingidentity.com/content/dam/ping-6-2-assets/topnav-json-configs/Ping-Logo.svg" width="80" height="80"  alt=""/>
  </picture>
</div>

`PingOidc` module provides OIDC client for PingOne and ForgeRock platform.

The `PingOidc` module follows the [OIDC](https://openid.net/specs/openid-connect-core-1_0.html) specification and
provides a simple and easy-to-use API to interact with the OIDC server. It allows you to authenticate, retrieve the
access token, revoke the token, and sign out from the OIDC server.

## Integrating the SDK into your project

Use Cocoapods or Swift Package Manger

## Oidc Client Configuration

Basic Configuration, use `discoveryEndpoint` to lookup OIDC endpoints

```swift
let config = OidcClientConfig()
config.discoveryEndpoint = "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/as/.well-known/openid-configuration"
config.clientId = "c12743f9-08e8-4420-a624-71bbb08e9fe1"
config.redirectUri = "org.forgerock.demo://oauth2redirect"
config.scopes = ["openid", "email", "address", "profile", "phone"]

let ping = OidcClient(config: config)

let result = await ping.token() // Retrieve the access token
switch result {
case .success(let token):
    let accessToken = token
case .failure(let error):
    switch error {
    case .apiError:
        //Address error
        break
    case .authorizeError:
        //Address error
        break
    case .networkError:
        //Address error
        break
    case .unknown:
        //Address error
        break
    }
}

await ping.revoke() //Revoke the access token
_ = await ping.endSession() //End the session
```

By default, the SDK uses `KeychainStorage` (with `SecuredKeyEncryptor` ) to store the token and `none` Logger is set,
however developers can override the storage and logger settings.

Basic Configuration with custom `storage` and `logger`

```swift
let config = OidcClientConfig()
config.logger = LogManager.standard //Log to console
config.storage = CustomStorage<Token>() //Use Custom Storage
//...

let ping = OidcClient(config: config)
```

More OidcClient configuration, configurable attribute can be found under
[OIDC Spec](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest)

```swift
let config = OidcClientConfig()
config.acrValues = "urn:acr:form"
config.loginHint = "test"
config.display = "test"
//...

let ping = OidcClient(config: config)
```

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
    
    func authorize(oidcConfig: PingOidc.OidcConfig<T>) async throws -> PingOidc.AuthCode {
        oidcConfig.config.config2 //Access the agent configuration
        oidcConfig.oidcClientConfig.openId?.endSessionEndpoint //Access the oidcClientConfig
        return AuthCode(code: "TestAgent", codeVerifier: "")
    }
    
    func endSession(oidcConfig: PingOidc.OidcConfig<CustomAgentConfig>, idToken: String) async throws -> Bool {
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
