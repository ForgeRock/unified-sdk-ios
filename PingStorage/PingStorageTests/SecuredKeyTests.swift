//
//  SecuredKeyTests.swift
//  PingStorageTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class SecuredKeyTests: XCTestCase {

  private var securedKey: SecuredKey!

     override func setUp() {
         super.setUp()
         securedKey = SecuredKey(applicationTag: "com.pingidentity.securedKey.identifier")
     }

     override func tearDown() {
         securedKey = nil
         super.tearDown()
     }

     func testEncryptAndDecrypt() {
         let data = "Test data".data(using: .utf8)!
         let encryptedData = securedKey.encrypt(data: data)
         XCTAssertNotNil(encryptedData)
         let decryptedData = securedKey.decrypt(data: encryptedData!)
         XCTAssertEqual(decryptedData, data)
     }
}
