<div>
  <picture>
     <img src="https://www.pingidentity.com/content/dam/ping-6-2-assets/topnav-json-configs/Ping-Logo.svg" width="80" height="80"  alt=""/>
  </picture>
</div>

# Orchestrate

## Overview

Orchestrate provides a simple way to build a state machine for ForgeRock Journey and PingOne DaVinci.
It allows you to define a series of states and transitions between them. You can use the workflow engine to build
complex workflows that involve multiple steps and conditions.
The Workflow engine allows you to define a series of functions and register them as a module to the `Workflow` instance
in different state of the workflow.

The Workflow engine contains the following states:

<img src="images/state.png" width="500">

| State      |              Description               |    Input |  Output |                                                                   Use Case |
|------------|:--------------------------------------:|---------:|--------:|---------------------------------------------------------------------------:|
| Init       |         Initialize the modules         |       () |    Void |                             OAuth module loads endpoint from discovery URL |
| Start      |             Start the flow             |  Request | Request |        Intercept the start request, for example inject forceAuth parameter |
| Response   |          Handle the response           | Response |    Void |                   Parse the response, for example store the cookie header. |
| *Transform |     Transform the response to Node     | Response |    Node | For Journey, transform response to Callback, for DaVinci transform to Form |
| Node       | Process the Node or Transform the Node |     Node |    Node |                             Transform MetadataCallback to WebAuthnCallback |
| Next       |           Move to next state           |  Request | Request |                                                 Inject noSession parameter |
| Success    |       Flow finished with Success       |  Success | Success |                                   Prepare Success with AuthCode or Session |
| SignOff    |          SignOff the Workflow          |  Request | Request |                                               Revoke Token and end session |

### Module

Module allows you to register functions in different state of the workflow. For example, you can register a function
that
will be called when the workflow is initialized,
when a node is received, when a node is sent, and when the workflow is started.

<img src="images/functions.png" width="500">

Information can be shared across state, there are 2 contexts

| Context         |                Scope                |                             Access |
|-----------------|:-----------------------------------:|-----------------------------------:|
| WorkflowContext |          Workflow Instance          |   ```context["name"] = "value" ``` |
| FlowContext     | Flow from Start to Finish (Success) | ```flowContext["name"]= "value"``` |

## Integrating the SDK into your project

Use Cocoapods or Swift Package Manger

## Usage

To use the `Workflow` class, you need to create an instance of it by passing a configuration block to the `createWorkflow` method. The
configuration block allows you to register various modules of the `Workflow` instance.

Here's an example of how to create a `Workflow` instance:

```swift
let workflow = Workflow.createWorkflow { config in
    config.module(forceAuth)
    config.module(noSession)
    config.module(session)
}
_ = await workflow.start()
```
The `start` method returns a `Node` instance. The `Node` class represents the current state of the application. You can
use the `next` method to transition to the next state.

### SignOff
There is a special state called `SignOff` that is used to sign off the user. You can use the `signOff` method to sign off
the user.

```swift
 _ = await workflow.signOff()
```

## Custom Module

You can provide a custom module to the `Workflow` instance. A module is a class that uses the `Module` interface.
The `Module` interface allows the module to install `function`s in different states during the `Workflow` flow.

```swift
let customHeader = Module.of({ CustomHeaderConfig1() }, setup: { setup in
    let config = setup.config
    // Intercept all send request and inject custom header
    setup.next { ( context, _, request) in
        if config.enable {
            request.header(name: config.headerName, value: config.headerValue)
        }
        return request
    }
})
```

You can then install the custom module in the `Workflow` configuration block like this:

```swift
let workflow = Workflow.createWorkflow { config in
    config.module(customHeader) { header in
        header.headerName = "iOS-SDK2"
        header.headerValue = "headervalue3"
    }
}
```

More module examples:
```swift
let nosession = Module.of { setup in
//Intercept all send request and inject custom header during start state
    setup.next { ( context,_, request) in
        request.header(name: "nosession", value: "true")
        return request
    }
}


let forceAuth = Module.of { setup in
//Intercept all send request and inject custom header during start state
    setup.start { ( context, request) in
        request.header(name: "forceAuth", value: "true")
        return request
    }
}
```
