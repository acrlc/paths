import Foundation
public struct FileFlag<Value>: Hashable {
 public var key: URLResourceKey
 public var path: KeyPath<URLResourceValues, Value>
}

public extension FileFlag {
 init(
  _ key: URLResourceKey, _ path: KeyPath<URLResourceValues, Value>
 ) {
  self.key = key
  self.path = path
 }
}

public extension FileFlag where Value == Bool? {
 static var hidden: Self { Self(.isHiddenKey, \.isHidden) }
 static var executable: Self { Self(.isExecutableKey, \.isExecutable) }
}

#if os(macOS) || os(iOS)
@available(macOS 11.0, iOS 14.0, *)
public extension FileFlag where Value == Int64? {
 static var contentIdentifier: Self {
  Self(.fileContentIdentifierKey, \.fileContentIdentifier)
 }
}

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public extension FileFlag where Value == Int64? {
 static var volumeAvailableCapacityForImportantUsage: Self {
  Self(.volumeAvailableCapacityForImportantUsageKey, \.volumeAvailableCapacityForImportantUsage)
 }
}

public extension FileFlag where Value == Int64? {
 static var volumeAvailableCapacityForOpportunisticUsage: Self {
  Self(.volumeAvailableCapacityForOpportunisticUsageKey, \.volumeAvailableCapacityForOpportunisticUsage)
 }
}
#endif

public extension FileFlag where Value == Int? {
 static var volumeAvailableCapacity: Self {
  Self(.volumeAvailableCapacityKey, \.volumeAvailableCapacity)
 }
}

public extension FileFlag where Value == String? {
 static var volumeName: Self { Self(.volumeNameKey, \.volumeName) }
}

//
// public extension FileFlag where Value == (NSCopying & NSSecureCoding & NSObjectProtocol)? {
// static var volumeIdentifier: Self { Self(.volumeIdentifierKey, \.volumeIdentifier) }
// }

public extension FileFlag where Value == URLFileResourceType? {
 static var fileResourceType: Self {
  Self(.fileResourceTypeKey, \.fileResourceType)
 }
}

#if canImport(UniformTypeIdentifiers)

@_exported import UniformTypeIdentifiers

@available(macOS 11.0, iOS 14.0, *)
public extension FileFlag where Value == UTType? {
 static var contentType: Self { Self(.contentTypeKey, \.contentType) }
}

#endif

public extension FileFlag where Value == String? {
 static var typeIdentifier: Self {
  Self(.typeIdentifierKey, \.typeIdentifier)
 }
}

public extension FileFlag where Value == (NSCopying & NSSecureCoding & NSObjectProtocol)? {
 static var fileResourceIdentifier: Self {
  Self(.fileResourceIdentifierKey, \.fileResourceIdentifier)
 }
}

#if os(macOS)
@available(macOS 13.3, *)
public extension FileFlag where Value == UInt64? {
 static var fileIdentifier: Self {
  Self(.fileIdentifierKey, \.fileIdentifier)
 }
}

public extension FileFlag where Value == [String]? {
 static var tagNames: Self { Self(.tagNamesKey, \.tagNames) }
}
#endif

public extension FileFlag where Value == String? {
 static var localizedTypeDescription: Self {
  Self(.localizedTypeDescriptionKey, \.localizedTypeDescription)
 }
}

public extension PathRepresentable {
 @inline(__always)
 /// Moves and renames file or folder if necessary
 subscript(_ path: String) -> String {
  get { self.path }
  set { try? storage.fileManager.moveItem(atPath: self.path, toPath: path) }
 }

 @inline(__always)
 func resourceValues(_ keys: Set<URLResourceKey>) throws -> URLResourceValues {
  try self.url.resourceValues(forKeys: keys)
 }

 @inline(__always)
 func resourceValue<Value>(_ flag: FileFlag<Value>) throws -> Value {
  try self.resourceValues([flag.key]).allValues[flag.key] as! Value
 }

 @inline(__always) func setResourceValues<Value>(
  _ newValue: Value, for flag: FileFlag<Value>
 ) throws {
  guard let path = flag.path as? WritableKeyPath else {
   fatalError("\(flag.path) for \(flag.key.rawValue) is immutable")
  }
  var values = try resourceValues([flag.key])
  values[keyPath: path] = newValue
 }

 @inline(__always)
 subscript<Value>(flag: FileFlag<Value>) -> Value {
  get throws { try self.resourceValue(flag) }
 }
}

// MARK: Attributes
public struct AttributeFlag<Value> {
 public var key: FileAttributeKey
 public var valueType: Value.Type
}

public extension AttributeFlag {
 init(
  _ key: FileAttributeKey, _ valueType: Value.Type
 ) {
  self.key = key
  self.valueType = valueType
 }
}

public extension AttributeFlag where Value == UInt64? {
 static var size: Self { Self(.size, UInt64?.self) }
}

public extension PathRepresentable {
 @inline(__always)
 subscript<Value>(attribute: AttributeFlag<Value>) -> Value {
  storage.attributes[attribute.key] as! Value
 }
}

public extension AttributeFlag where Value == Date {
 static var modificationDate: Self { Self(.modificationDate, Date.self) }
}

public extension AttributeFlag where Value == Date {
 static var creationDate: Self { Self(.creationDate, Date.self) }
}

public extension AttributeFlag where Value == NSNumber {
 static var systemFileNumber: Self { Self(.systemFileNumber, NSNumber.self) }
}
