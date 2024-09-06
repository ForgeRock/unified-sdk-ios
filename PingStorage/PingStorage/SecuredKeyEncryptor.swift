//
//  SecuredKeyEncryptor.swift
//  PingStorage
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A struct that provides encryption and decryption functionalities using `SecuredKey`.
public struct SecuredKeyEncryptor: Encryptor {
  private let securedKeyTag: String = "com.pingidentity.securedKey.identifier"
  private var securedKey: SecuredKey
  
  /// Initializes a new instance of `SecuredKeyEncryptor`.
  ///
  /// This initializer attempts to create a `SecuredKey` with the given application tag.
  /// If it fails, the initializer returns `nil`.
  public init?() {
    guard let securedKey = SecuredKey(applicationTag: self.securedKeyTag) else {
      return nil
    }
    self.securedKey = securedKey
  }
  
  /// Encrypts the given data.
  /// - Parameter data: The data to encrypt.
  /// - Returns: The encrypted data.
  /// - Throws: `EncryptorError.failedToEncrypt` if the encryption fails.
  public func encrypt(data: Data) async throws -> Data {
    guard let encryptedData = securedKey.encrypt(data: data) else {
      throw EncryptorError.failedToEncrypt
    }
    return encryptedData
  }
  
  // Decrypts the given data.
  /// - Parameter data: The data to decrypt.
  /// - Returns: The decrypted data.
  /// - Throws: `EncryptorError.failedToDecrypt` if the decryption fails.
  public func decrypt(data: Data) async throws -> Data {
    guard let decryptedData = securedKey.decrypt(data: data) else {
      throw EncryptorError.failedToDecrypt
    }
    return decryptedData
  }
}


/// `EncryptorError` represents errors that can occur while encrypting/decrypting.
public enum EncryptorError: LocalizedError {
  case failedToEncrypt
  case failedToDecrypt
  
  var errorMessage: String {
    switch self {
    case .failedToEncrypt:
      return "Failed to encrypt given data"
    case .failedToDecrypt:
      return "Failed to decrypt given data"
    }
  }
}
