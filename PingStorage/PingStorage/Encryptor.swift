//
//  Encryptor.swift
//  PingStorage
//
//  Copyright (c) 2024 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A protocol that defines methods for encrypting and decrypting data.
public protocol Encryptor {
  /// Encrypts the given data.
  /// - Parameter data: The data to encrypt.
  /// - Returns: The encrypted data.
  /// - Throws: An error if encryption fails.
  func encrypt(data: Data) async throws -> Data
  
  // Decrypts the given data.
  /// - Parameter data: The data to decrypt.
  /// - Returns: The decrypted data.
  /// - Throws: An error if decryption fails.
  func decrypt(data: Data) async throws -> Data
}


/// A struct that provides no encryption.
public struct NoEncryptor: Encryptor {
  /// Initializes a new instance of `NoEncryptor`.
  public init() {}
  
  /// Returns the given data without performing any encryption.
  ///
  /// - Parameter data: The data to "encrypt".
  /// - Returns: The same data that was provided.
  public func encrypt(data: Data) async throws -> Data {
    return data
  }
  
  /// Returns the given data without performing any decryption.
  ///
  /// - Parameter data: The data to "decrypt".
  /// - Returns: The same data that was provided.
  public func decrypt(data: Data) async throws -> Data {
    return data
  }
}
