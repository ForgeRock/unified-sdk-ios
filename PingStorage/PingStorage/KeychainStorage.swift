//
//  KeychainStorage.swift
//  PingStorage
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A storage for storing `Codable` objects in the Keychain
public class Keychain<T: Codable>: Storage {
  private var account: String
  private let service: String = "com.pingidentity.keychainService"
  private let encryptor: Encryptor
  
  /// Initializer for Keychain
  /// - Parameters:
  ///   - account: String indicating the item's account(key) name.
  ///   - encryptor: Encryptor for encrypting stored data. Default value is `NoEncryptor()`
  public init(account: String, encryptor: Encryptor = NoEncryptor()) {
    self.account = account
    self.encryptor = encryptor
  }
  
  /// Saves the given item in the keychain.
  /// - Parameter item: The item to save.
  public func save(item: T) async throws {
    let data = try JSONEncoder().encode(item)
    var query = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecAttrService as String: service,
      kSecValueData as String: data
    ] as [String: Any]

    query[kSecValueData  as String] = try await encryptor.encrypt(data: data)

    SecItemDelete(query as CFDictionary) // Remove any existing item
    let status = SecItemAdd(query as CFDictionary, nil)

    guard status == errSecSuccess else {
      throw KeychainError.unableToSave
    }
  }

  /// Retrieves the item from the keychain.
  /// - Returns: The item if it exists, null otherwise.
  public func get() async throws -> T? {
    let query = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecAttrService as String: service,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: kCFBooleanTrue!
    ] as [String: Any]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status == errSecSuccess, let data = item as? Data else {
      return nil
    }

    return try JSONDecoder().decode(T.self, from: try await encryptor.decrypt(data: data))
  }

  /// Deletes the item from memory.
  public func delete() async throws {
    let query = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecAttrService as String: service
    ] as [String: Any]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess else {
      throw KeychainError.unableToDelete
    }
  }
}

/// `KeychainError` represents errors that can occur while interacting with the keychain.
public enum KeychainError: LocalizedError {
  case unableToSave
  case unableToRetrieve
  case unableToDelete
  
  var errorMessage: String {
    switch self {
    case .unableToSave:
      return "Uanble to save to the keychain"
    case .unableToRetrieve:
      return "Uanble to retrieve from the keychain"
    case .unableToDelete:
      return "Unable to delete from the kechain"
    }
  }
}

/// `KeychainStorage` is a generic class that conforms to the `StorageDelegate` protocol, providing a secure storage solution by leveraging the keychain.
/// It is designed to store, retrieve, and manage objects of type `T`, where `T` must conform to the `Codable` protocol. This requirement ensures that the objects can be easily encoded and decoded for secure storage in the keychain.
///
/// - Parameter T: The type of the objects to be stored in the keychain. Must conform to `Codable`.
public class KeychainStorage<T: Codable>: StorageDelegate<T> {
  /// Initializes a new instance of `KeychainStorage`.
  ///
  /// This initializer configures a `KeychainStorage` instance with a specified account and security settings.
  /// It allows storing data securely in the keychain using the provided account identifier. T
  ///
  /// - Parameters:
  ///   - account: A `String` identifying the keychain account under which the data will be stored. This is used
  ///              to differentiate between different sets of data within the keychain.
  ///   - encryptor: An `Encryptor` instance for encrypting/decrypting the stored data. Default value is `NoEncryptor()`
  ///   - cacheable: A `Bool` indicating whether the stored data should be cached. Defaults to `false`.
  public init(account: String, encryptor: Encryptor = NoEncryptor(), cacheable: Bool = false) {
    super.init(delegate: Keychain<T>(account: account, encryptor: encryptor), cacheable: cacheable)
  }
}
