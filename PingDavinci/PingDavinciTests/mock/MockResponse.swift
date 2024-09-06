// 
//  MockResponse.swift
//  PingDavinciTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

struct MockResponse {
    static let headers = ["Content-Type": "application/json"]
    
    // Freturn the OpenID configuration response as Data
    static var openIdConfigurationResponse: Data {
        return """
        {
            "authorization_endpoint" : "http://auth.test-one-pingone.com/authorize",
            "token_endpoint" : "https://auth.test-one-pingone.com/token",
            "userinfo_endpoint" : "https://auth.test-one-pingone.com/userinfo",
            "end_session_endpoint" : "https://auth.test-one-pingone.com/signoff",
            "revocation_endpoint" : "https://auth.test-one-pingone.com/revoke"
        }
        """.data(using: .utf8)!
    }
    
    // return the token response as Data
    static var tokenResponse: Data {
        return """
        {
            "access_token" : "Dummy AccessToken",
            "token_type" : "Dummy Token Type",
            "scope" : "openid email address",
            "refresh_token" : "Dummy RefreshToken",
            "expires_in" : 1,
            "id_token" : "Dummy IdToken"
        }
        """.data(using: .utf8)!
    }
    
    // return the userinfo response as Data
    static var userinfoResponse: Data {
        return """
        {
            "sub" : "test-sub",
            "name" : "test-name",
            "email" : "test-email",
            "phone_number" : "test-phone_number",
            "address" : "test-address"
        }
        """.data(using: .utf8)!
    }
    
    //  return an empty revoke response as Data
    static var revokeResponse: Data{
        return Data()
    }
    
    // Headers for the authorize response
    static let authorizeResponseHeaders: [String: String] =
    [
        "Content-Type": "application/json; charset=utf-8",
        "Set-Cookie": """
        interactionId=038e8128-272a-4a15-b97b-379aa1447149; Max-Age=3600; Path=/; Expires=Wed, 27 Mar 9999 05:06:30 GMT; HttpOnly
        """,
//        "Set-Cookie": """
//        interactionToken=71c65504463355679fd247900441c36afb6be6c00d45aa169500b7cd753894d46d68feb4952ff0843ff4b287220a66cb3d58a3bc41e71724f111b034d0458aac8a5153859ed96825ef8c6a6400e7ae9de82a7353fc3c9886ba835853db8c0957ea4cd0a52d20d4fb50b4419dc9df33a53889f52abeb04f517b6c7c8efb0b58f0; Max-Age=3600; Path=/; Expires=Wed, 27 Mar 9999 05:06:30 GMT; HttpOnly
//        """,
//        "Set-Cookie": """
//        skProxyApiEnvironmentId=us-west-2; Max-Age=900; Path=/; Expires=Wed, 27 Mar 9999 04:21:30 GMT; HttpOnly
//        """
    ]
    
    // return the authorize response as Data
    static var authorizeResponse: Data {
        return """
        {
            "_links": {
                "next": {
                    "href": "http://auth.test-one-pingone.com/customHTMLTemplate"
                }
            },
            "interactionId": "008bccea-914b-49da-b2a1-5cd3f83f4372",
            "interactionToken": "2a0d9bcdbdeb5ea14ef34d680afc45f37a56e190e306a778f01d768b271bf1e976aaf4154b633381e1299b684d3a4a66d3e1c6d419a7d20657bf4f32c741d78f67d41e08eb0e5f1070edf780809b4ccea8830866bcedb388d8f5de13e89454d353bcca86d4dcd5d7872efc929f7e5199d8d127d1b2b45499c42856ce785d8664",
            "eventName": "continue",
            "isResponseCompatibleWithMobileAndWebSdks": true,
            "id": "cq77vwelou",
            "companyId": "0c6851ed-0f12-4c9a-a174-9b1bf8b438ae",
            "flowId": "ebac77c8fbf68d3dac68c5dd804a936f",
            "connectionId": "867ed4363b2bc21c860085ad2baa817d",
            "capabilityName": "customHTMLTemplate",
            "formData": {
                "value": {
                    "username": "",
                    "password": ""
                }
            },
            "form": {
                "name": "Username/Password Form",
                "description": "Test Description",
                "category": "CUSTOM_HTML",
                "components": {
                    "fields": [
                        {
                            "type": "TEXT",
                            "key": "username",
                            "label": "Username"
                        },
                        {
                            "type": "PASSWORD",
                            "key": "password",
                            "label": "Password"
                        },
                        {
                            "type": "SUBMIT_BUTTON",
                            "key": "SIGNON",
                            "label": "Sign On"
                        },
                        {
                            "type": "FLOW_BUTTON",
                            "key": "TROUBLE",
                            "label": "Having trouble signing on?"
                        },
                        {
                            "type": "FLOW_BUTTON",
                            "key": "REGISTER",
                            "label": "No account? Register now!"
                        }
                    ]
                }
            }
        }
        """.data(using: .utf8)!
    }
    
    // Headers for the custom HTML template response
    static let customHTMLTemplateHeaders: [String: String] = [
        "Content-Type": "application/json; charset=utf-8",
        "Set-Cookie": """
        ST=session_token; Max-Age=3600; Path=/; Expires=Wed, 27 Mar 9999 05:06:30 GMT; HttpOnly
        """
    ]
    
    // return the custom HTML template response as Data
    static var customHTMLTemplate: Data {
        return """
        {
            "interactionId": "033e1338-c271-4dd7-8d74-fc2eacc135d8",
            "companyId": "94e3268d-847d-47aa-a45e-1ef8dd8f4df0",
            "connectionId": "26146c8065741406afb0899484e361a7",
            "connectorId": "pingOneAuthenticationConnector",
            "id": "5dtrjnrwox",
            "capabilityName": "returnSuccessResponseRedirect",
            "environment": {
                "id": "94e3268d-847d-47aa-a45e-1ef8dd8f4df0"
            },
            "session": {
                "id": "d0598645-c2f7-4b94-adc9-401a896eaffb"
            },
            "status": "COMPLETED",
            "authorizeResponse": {
                "code": "03dbd5a2-db72-437c-8728-fc33b860083c"
            },
            "success": true,
            "interactionToken": "5ad09feac8982d668c5f07d1eaf544bdf2309247146999c0139f7ebb955c24743b97a01e3bf67360121cd85d7a9e1d966c3f4b7e27f21206a5304d305951864cc34a37900f3326f8000c7bc731af9ba78a681eb14d4bf767172e8a7149e4df3e054b4245bdea5612e9ec0c0d8cb349b55dcf10db30de075dfc79f6c765046d99"
        }
        """.data(using: .utf8)!
    }
    
    // return the custom HTML template response with invalid password as Data
    static var customHTMLTemplateWithInvalidPassword: Data {
        return """
        {
            "interactionId": "00444ecd-0901-4b57-acc3-e1245971205b",
            "companyId": "0c6851ed-0f12-4c9a-a174-9b1bf8b438ae",
            "connectionId": "94141bf2f1b9b59a5f5365ff135e02bb",
            "connectorId": "pingOneSSOConnector",
            "id": "dnu7jt3sjz",
            "capabilityName": "checkPassword",
            "errorCategory": "NotSet",
            "code": "Invalid username and/or password",
            "cause": null,
            "expected": true,
            "message": "Invalid username and/or password",
            "httpResponseCode": 400,
            "details": [
                {
                    "rawResponse": {
                        "id": "b187c1c7-e9fe-4f72-a554-1b2876babafe",
                        "code": "INVALID_DATA",
                        "message": "The request could not be completed. One or more validation errors were in the request.",
                        "details": [
                            {
                                "code": "INVALID_VALUE",
                                "target": "password",
                                "message": "The provided password did not match provisioned password",
                                "innerError": {
                                    "failuresRemaining": 4
                                }
                            }
                        ]
                    },
                    "statusCode": 400
                }
            ],
            "isResponseCompatibleWithMobileAndWebSdks": true,
            "correlationId": "b187c1c7-e9fe-4f72-a554-1b2876babafe"
        }
        """.data(using: .utf8)!
    }
    
    static var tokenErrorResponse: Data {
        return """
        {
            "error": "Invalid Grant"
        }
        """.data(using: .utf8)!
    }
}
