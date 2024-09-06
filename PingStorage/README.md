<div>
  <picture>
     <img src="https://www.pingidentity.com/content/dam/ping-6-2-assets/topnav-json-configs/Ping-Logo.svg" width="80" height="80"  alt=""/>
  </picture>
</div>

# Ping Storage SDK

The Ping Storage SDK provides a flexible storage interface and a set of common storage solutions for the Ping SDKs.

## Integrating the SDK into your project

Use Cocoapods or Swift Package Manger

## How to Use the SDK

### Creating and Using a Storage Instance

To create a storage instance and use it to persist and retrieve data, follow the example below:

```swift
// Define the data type that you want to persist
struct Dog: Codable {
    let name: String
    let type: String
}

  let storage = KeychainStorage<Dog>(account: "myId") // Create the storage
  try? await storage.save(item: Dog(name: "Lucky", type: "Golden Retriever")) // Persist the item
  let storedData = try? await storage.get() // Retrieve the item
```

Keychain is a storage solution that
uses iOS Keychain to store data securely.

### Enabling Cache for the Storage

You can enable cache for the storage as follows, by default cache is disabled:

```swift
  let storage = KeychainStorage<Dog>(account: "myId", cacheable: true) // Create the Storage with cache enabled
```

### Adding Encryption to the Storage

You can add encryption by specifying the encryptor (`Encryptor` instance) as follows, by default `NoEncryptor` is used:

```swift
  let storage = KeychainStorage<Dog>(account: "myId", encryptor: SecuredKeyEncryptor() ?? NoEncryptor(), cacheable: true) // Create the Storage with `SecuredKeyEncryptor`
```

You can create your custom encryptor by implementing the `Encryptor` protocol:

```swift
struct MyEncryptor: Encryptor {
  func encrypt(data: Data) async throws -> Data {
    // Implement the encryption logic
  }

  func decrypt(data: Data) async throws -> Data {
    // Implement the decryption logic
  }
}
```

### Creating a Custom Storage

You can create a custom storage by implementing the `Storage` interface. This could be useful for creating
file-based storage, cloud storage, etc. Here is an example of creating a custom memory storage:

```swift
public class CustomStorage<T: Codable>: Storage {
  private var data: T?

  public func save(item: T) async throws {
    data = item
  }

  public func get() async throws -> T?  {
    return data
  }

  public func delete() async throws {
    data = nil
  }

}

public class CustomStorageDelegate<T: Codable>: StorageDelegate<T> {
  public init(cacheable: Bool = false) {
    super.init(delegate: CustomStorage<T>(), cacheable: cacheable)
  }
}

```

## Available Storage Solutions

The Ping Storage SDK provides the following storage solutions:

| Storage          | Description                                                                                                                                 |
|------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| KeychainStorage  | Storage that stores data in iOS Keychain.                                                                                                    |
| MemoryStorage    | Storage that stores data in memory.                                                                                                          |
