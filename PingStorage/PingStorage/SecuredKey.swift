//
//  SecuredKey.swift
//  PingStorage
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import LocalAuthentication
import CryptoKit

/// SecuredKey is a representation of Secure Enclave keypair and performing PKI using Secure Enclave
public struct SecuredKey {

  /// Private Key of SecuredKey
  fileprivate var privateKey: SecKey
  /// Public Key of SecuredKey
  fileprivate var publicKey: SecKey
  /// Algorithm to be used for encryption/decryption using SecuredKey
  fileprivate let oldAlgorithm: SecKeyAlgorithm = .eciesEncryptionCofactorX963SHA256AESGCM

  /// Validates whether SecuredKey using Secure Enclave is available on the device or not
  public static func isAvailable() -> Bool {

    return SecureEnclave.isAvailable
  }

  /// Initializes SecuredKey object with designated service; SecuredKey may return nil if it failed to generate keypair
  /// - Parameter applicationTag: Unique identifier for SecuredKey
  public init?(applicationTag: String) {

    guard SecuredKey.isAvailable() else {
      return nil
    }

    // If SecuredKey already exists, return from the storage
    if let privateKey = SecuredKey.readKey(applicationTag: applicationTag) {
      self.privateKey = privateKey
    }
    else {
      // Otherwise, generate new keypair
      do {
        self.privateKey = try SecuredKey.generateKey(applicationTag: applicationTag, accessGroup: nil, accessibility: kSecAttrAccessibleAfterFirstUnlock)
      }
      catch {
        return nil
      }
    }

    // Copy the public key from the private key
    if let publicKey = SecKeyCopyPublicKey(self.privateKey) {
      self.publicKey = publicKey
    }
    else {
      return nil
    }
  }

  /// Retrieves private key with given 'ApplicationTag'
  /// - Parameter applicationTag: Application Tag string value for private key
  static func readKey(applicationTag: String, accessGroup: String? = nil) -> SecKey? {
    var query = [String: Any]()
    query[String(kSecClass)] = kSecClassKey
    query[String(kSecAttrKeyType)] = String(kSecAttrKeyTypeEC)
    query[String(kSecReturnRef)] = true
    query[String(kSecAttrApplicationTag)] = applicationTag

    if let accessGroup = accessGroup {
      query[String(kSecAttrAccessGroup)] = accessGroup
    }

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess else {
      return nil
    }
    return (item as! SecKey)
  }

  /// Generates private key with given 'ApplicationTag'
  /// - Parameter applicationTag: Application Tag string value for private key
  static func generateKey(applicationTag: String, accessGroup: String? = nil, accessibility: CFString) throws -> SecKey {
    var query = [String: Any]()

    query[String(kSecAttrKeyType)] = String(kSecAttrKeyTypeEC)
    query[String(kSecAttrKeySizeInBits)] = 256

    if let accessGroup = accessGroup {
      query[String(kSecAttrAccessGroup)] = accessGroup
    }

    var keyAttr = [String: Any]()
    keyAttr[String(kSecAttrIsPermanent)] = true
    keyAttr[String(kSecAttrApplicationTag)] = applicationTag

#if !targetEnvironment(simulator)
    // If the device supports Secure Enclave, create a keypair using Secure Enclave TokenID
    if SecuredKey.isAvailable() {
      query[String(kSecAttrTokenID)] = String(kSecAttrTokenIDSecureEnclave)
      let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault, accessibility, .privateKeyUsage, nil)!
      keyAttr[String(kSecAttrAccessControl)] = accessControl
    }
#endif

    query[String(kSecPrivateKeyAttrs)] = keyAttr

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(query as CFDictionary, &error) else {
      throw error!.takeRetainedValue() as Error
    }

    return privateKey
  }

  /// Deletes private key with given 'Application Tag'
  /// - Parameter applicationTag: Application Tag string value for private key
  static func deleteKey(applicationTag: String) {
    var query = [String: Any]()
    query[String(kSecClass)] = String(kSecClassKey)
    query[String(kSecAttrApplicationTag)] = applicationTag
    SecItemDelete(query as CFDictionary)
  }

  /// Encrypts Data object using SecuredKey object
  /// - Parameter data: Encrypted Data object
  public func encrypt(data: Data, secAlgorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM) -> Data? {

    guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, secAlgorithm) else {
      return nil
    }

    var error: Unmanaged<CFError>?
    let encryptedData = SecKeyCreateEncryptedData(publicKey, secAlgorithm, data as CFData, &error) as Data?
    return encryptedData
  }

  /// Decrypts Data object using SecuredKey object
  /// - Parameter data: Decrypted Data object
  public func decrypt(data: Data, secAlgorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM) -> Data? {

    guard SecKeyIsAlgorithmSupported(privateKey, .decrypt, secAlgorithm) else {
      return nil
    }

    var error: Unmanaged<CFError>?
    let decryptedData = SecKeyCreateDecryptedData(privateKey, secAlgorithm, data as CFData, &error) as Data?
    if error != nil {
      var decryptError: Unmanaged<CFError>?
      let decryptedData = SecKeyCreateDecryptedData(privateKey, oldAlgorithm, data as CFData, &decryptError) as Data?
      if decryptError != nil {
        return nil
      } else {
        return decryptedData
      }

    }
    return decryptedData
  }
}
