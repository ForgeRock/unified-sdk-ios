//
//  CustomEncryptorTests.swift
//  PingStorageTests
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingStorage

final class CustomEncryptorTests: XCTestCase {
  var encryptor: CustomEncryptor!
  
  override func setUp() {
    super.setUp()
    encryptor = CustomEncryptor()
  }
  
  override func tearDown() {
    encryptor = nil
    super.tearDown()
  }
  
  func testEncryption() async {
    let data = Data("Test data".utf8)
    
    do {
      let encryptedData = try await encryptor.encrypt(data: data)
      let encryptedString = String(decoding: encryptedData, as: UTF8.self)
      XCTAssertTrue(encryptedString.contains("_ENCRYPTED_"), "Encrypted data should contain '_ENCRYPTED_'")
    } catch {
      XCTFail("Encryption failed with error: \(error)")
    }
  }
  
  func testDecryption() async {
    let data = Data("Test data".utf8)
    let encryptedData = try! await encryptor.encrypt(data: data)
    
    do {
      let decryptedData = try await encryptor.decrypt(data: encryptedData)
      let decryptedString = String(decoding: decryptedData, as: UTF8.self)
      XCTAssertEqual(decryptedString, "Test data", "Decrypted data should match original data")
    } catch {
      XCTFail("Decryption failed with error: \(error)")
    }
  }
}

struct CustomEncryptor: Encryptor {
  
  func encrypt(data: Data) async throws -> Data {
    let stringData = String(decoding: data, as: UTF8.self)
    let encryptedString = stringData + "_ENCRYPTED_"
    return Data(encryptedString.utf8)
  }
  
  func decrypt(data: Data) async throws -> Data {
    let stringData = String(decoding: data, as: UTF8.self)
    let decryptedString = stringData.replacingOccurrences(of: "_ENCRYPTED_", with: "")
    return Data(decryptedString.utf8)
  }
}
