<div>
  <picture>
     <img src="https://www.pingidentity.com/content/dam/ping-6-2-assets/topnav-json-configs/Ping-Logo.svg" width="80" height="80"  alt=""/>
  </picture>
</div>

# DaVinci

## Overview

DaVinci is a powerful and flexible library for Authentication and Authorization. It is designed to be easy to use and
extensible. It provides a simple API for navigating the authentication flow and handling the various states that can
occur during the authentication process.

<img src="images/davinciSequence.png" width="500">

## Integrating the SDK into your project

Use Cocoapods or Swift Package Manger

## Usage

To use the `DaVinci` class, you need to create an instance of it by passing a configuration block to the `createDaVinci` method. The
configuration block allows you to customize various aspects of the `DaVinci` instance, such as the timeout and logging.

Here's an example of how to create a `DaVinci` instance:

```swift
let daVinci = DaVinci.createDaVinci { config in
            // Oidc as module
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "test"
                oidcValue.discoveryEndpoint = "https://auth.test-one-pingone.com/0c6851ed-0f12-4c9a-a174-9b1bf8b438ae/as/.well-known/openid-configuration"
                oidcValue.scopes = ["openid", "email", "address"]
                oidcValue.redirectUri = "org.forgerock.demo://oauth2redirect"
            }
        }
var node = await daVinci.start()
node = await (node as! ContinueNode).next()
```

The `DaVinci` depends on `PingOidc` module. It discovers the OIDC endpoints with `discoveryEndpoint` attribute.

The `start` method returns a `Node` instance. The `Node` class represents the current state of the application. You can
use the `next` method to transition to the next state.

## More DaVinci Configuration
```swift
let daVinci = DaVinci.createDaVinci { config in
    config.timeout = 30
    config.logger = LogManager.standard
    config.module(OidcModule.config) { oidcValue in
        //...
        oidcValue.storage = MemoryStorage<Token>()
    }
}
```


### Navigate the authentication Flow

```swift
let node = await daVinci.start() //Start the flow

//Determine the Node Type
switch (node) {
case is ContinueNode: do {}
case is ErrorNode: do {}
case is FailureNode: do {}
case is SuccessNode: do {}
        }
```

| Node Type  | Description                                                                                               |
|------------|:----------------------------------------------------------------------------------------------------------|
| ContinueNode  | In the middle of the flow, call ```node.next``` to move to next Node in the flow                          |
| FailureNode  | Unexpected Error, e.g Network, parsing ```node.cause``` to retrieve the cause of the error                |
| ErrorNode| Bad Request from the server, e.g Invalid Password, OTP, username ```node.message``` for the error message |
| SuccessNode| Authentication successful ```node.session``` to retrieve the session                                      |

### Provide input
For `ContinueNode` Node, you can access list of Collector with `node.collectors` and provide input to
the `Collector`.
Currently, there are, `TextCollector`, `PasswordCollector`, `SubmitCollector`, `FlowCollector`, but more will be added in the future, such as `Fido`,
`SocialLoginCollector`, etc...

To access the collectors, you can use the following code:
```swift
node.collectors.forEach { item in
    switch(item) {
    case is TextCollector:
        (item as! TextCollector).value = "My First Name"
    case is PasswordCollector:
        (item as! PasswordCollector).value = "My Password"
    case is SubmitCollector:
        (item as! SubmitCollector).value = "click me"
    case is FlowCollector:
        (item as! FlowCollector).value = "Forgot Password"
    }
}

//Move to next Node, and repeat the flow until it reaches `SuccessNode` or `ErrorNode` Node
let next = node.next()
```

### Error Handling

For `FailureNode` Node, you can retrieve the cause of the error by using `node.cause`. The `cause` is an `Error` instance,
when receiving an error, you cannot continue the Flow, you may want to display a generic message to the user, and report
the issue to the Support team.
The Error may include Network issue, parsing issue, API Error (Server response other that 2xx and 400) and other unexpected issues.

For `ErrorNode` Node, you can retrieve the error message by using `node.message`. The `message` is a `String` object,
when receiving a failure, you can continue the Flow with previous `ContinueNode` Node, but you may want to display the error message to the user.
e.g "Username/Password is incorrect", "OTP is invalid", etc...
```swift
let node = await daVinci.start() //Start the flow

//Determine the Node Type
switch (node) {
case is ContinueNode: do {}
case is FailureNode:
    (node as! FailureNode).cause //Retrieve the cause of the Failure
case is ErrorNode:
    (node as! ErrorNode).message //Retrieve the error message
case is SuccessNode: do {}
}
```

### Node Identifier
You can use the `node.id` to identify the current state of the flow. The `id` is a unique identifier for each node.

For example, you can use the `id` to determine if the current state is `Forgot Passowrd`, `Registration`, etc....

```swift

var state = ""
switch (node.id) {
case "cq77vwelou": state = "Sign On"
case  "qwnvng32z3": state = "Password Reset"
case "4dth5sn269": state = "Create Your Profile"
case "qojn9nsdxh": state = "Verification Code"
case "fkekf3oi8e": state =  "Enter New Password"
default: state = ""
}
```

Other than `id`, you can also use `node.name` to retrieve the name of the Node, `node.description` to retrieve the description of the Node.


### Work with SwiftUI

ViewModel
```swift
//Define State that listen by the View

@Published var state: Node = EmptyNode()

//Start the DaVinci flow
let next = await daVinci.start()

//Update the state
state = next

func next(node: ContinueNode) {
   val next = await node.next()
   state = next
    
}
```

View
```swift
if let node = state.node {
    switch node {
    case is ContinueNode:
        // Handle ContinueNode case
        break
    case is ErrorNode:
        // Handle Error case
        break
    case is FailureNode:
        // Handle Failure case
        break
    case is SuccessNode:
        // Handle Success case
        break
    default:
        break
    }
}
```

### Post Authentication
After authenticate with DaVinci, the user session will be stored in the storage.
To retrieve the existing session, you can use the following code:

```swift
//Retrieve the existing user, if token exists in the storage, ```user``` will be not nil.
//However, even with the user object, you may not be able to retrieve a valid token, as the token and refresh token may be expired.

let user: User? = await daVinci.user()

_ = await user?.token()
await user?.revoke()
_ = await user?.userinfo(cache: false)
await user?.logout()

```
