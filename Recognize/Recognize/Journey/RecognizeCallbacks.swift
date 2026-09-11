//
//  RecognizeCallbacks.swift
//  PingRecognize
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

#if canImport(KeylessSDK)
import Foundation
import PingJourneyPlugin

@objc
class RecognizeCallbacks: NSObject {
    /// Registers the PingOneRecognizeCallback with the Journey callback registry.
    @objc
    public static func registerCallbacks() {
        Task {
            await CallbackRegistry.shared.register(
                type: JourneyConstants.pingOneRecognizeCallback,
                callback: RecognizeCallback.self
            )
        }
    }
}

extension JourneyConstants {
    public static let pingOneRecognizeCallback = "PingOneRecognizeCallback"
}
#endif
