//
//  SecuredKeyEncryptorTests.swift
//  PingStorageTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingStorage

final class SecuredKeyEncryptorTests: XCTestCase {
  
  var encryptor: SecuredKeyEncryptor?
  
  override func setUp() {
    super.setUp()
    encryptor = SecuredKeyEncryptor()
  }
  
  override func tearDown() {
    encryptor = nil
    super.tearDown()
  }
  
  func testInitialization() {
    XCTAssertNotNil(encryptor, "Initialization should succeed")
  }
  
  func testEncryption() async {
    let data = Data("Test data".utf8)
    
    do {
      let encryptedData = try await encryptor?.encrypt(data: data)
      XCTAssertNotNil(encryptedData, "Encryption should succeed")
    } catch {
      XCTFail("Encryption failed with error: \(error)")
    }
  }
  
  func testDecryption() async {
    let data = Data("Test data".utf8)
    
    do {
      let encryptedData = try await encryptor?.encrypt(data: data)
      let decryptedData = try await encryptor?.decrypt(data: encryptedData!)
      
      XCTAssertNotNil(decryptedData, "Decryption should succeed")
      XCTAssertEqual(decryptedData, data, "Decrypted data should match original data")
    } catch {
      XCTFail("Decryption failed with error: \(error)")
    }
  }
}
