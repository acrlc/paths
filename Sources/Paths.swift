import Foundation
/// Enum describing various types of locations that can be found on a file system.
public enum PathType: String, CustomStringConvertible {
 /// A file can be found at the location.
 case file
 /// A folder can be found at the location.
 case folder
 public var description: String { self.rawValue }
}

/// Protocol adopted by types that represent locations on a file system.
public protocol PathRepresentable:
 Equatable, LosslessStringConvertible, Hashable {
 /// The type of location that is being represented (see `PathType`).
 static var type: PathType { get }
 /// The underlying storage for the item at the represented location.
 /// You don't interact with this object as part of the public API.
 var storage: Storage<Self> { get }
 var path: String { get }
 /// Initialize an instance of this location with its underlying storage.
 /// You don't call this initializer as part of the public API, instead
 /// use `init(path:)` on either `File` or `Folder`.
 init(storage: Storage<Self>)
}

public typealias Path = any PathRepresentable

public extension PathRepresentable {
 static func == (lhs: Self, rhs: Self) -> Bool {
  lhs.storage.path == rhs.storage.path
 }

 var description: String {
  Self.type == .file ? self.path.removingSuffix("/") : self.path
 }

 func hash(into hasher: inout Hasher) { hasher.combine(self.path) }

 /// The path of this location, relative to the root of the file system.
 var path: String {
  storage.path
 }

 /// A URL representation of the location's `path`.
 var url: URL {
  URL(fileURLWithPath: self.path)
 }

 /// The name of the location, including any `extension`.
 var name: String {
  self.url.pathComponents.last!
 }

 var exists: Bool {
  storage.fileManager.locationExists(at: path, type: Self.type)
 }

 /// The name of the location, excluding its `extension`.
 var nameExcludingExtension: String {
  guard let lastIndex = name.lastIndex(where: { $0 == "." })
  else { return self.name }
  return String(self.name[self.name.startIndex ..< lastIndex])
 }

 /// The file extension of the item at the location.
 var `extension`: String? {
  guard let startIndex = name.lastIndex(where: { $0 == "." }),
        startIndex != name.startIndex
  else { return nil }
  return String(self.name[self.name.index(after: startIndex) ..< self.name.endIndex])
 }

 /// The parent folder that this location is contained within.
 var parent: Folder? {
  storage.makeParentPath(for: self.path).flatMap {
   try? Folder(path: $0)
  }
 }

 /// The date when the item at this location was created.
 /// Only returns `nil` in case the item has now been deleted.
 var creationDate: Date? {
  storage.attributes[.creationDate] as? Date
 }

 /// The date when the item at this location was last modified.
 /// Only returns `nil` in case the item has now been deleted.
 var modificationDate: Date? {
  storage.attributes[.modificationDate] as? Date
 }

 /// Initialize an instance of an existing location at a given path.
 /// - parameter path: The absolute path of the location.
 /// - throws: `PathError` if the item couldn't be found.
 init(path: String) throws {
  try self.init(storage: Storage(
   path: path,
   fileManager: .default
  ))
 }

 init?(_ description: String) {
  try? self.init(path: description)
 }

 /// Return the path of this location relative to a parent folder.
 /// For example, if this item is located at `/users/john/documents`
 /// and `/users/john` is passed, then `documents` is returned. If the
 /// passed folder isn't an ancestor of this item, then the item's
 /// absolute `path` is returned instead.
 /// - parameter folder: The folder to compare this item's path against.
 func path(relativeTo folder: Folder) -> String {
  guard self.path.hasPrefix(folder.path) else {
   return self.path
  }

  let index = self.path.index(self.path.startIndex, offsetBy: folder.path.count)
  return String(self.path[index...]).removingSuffix("/")
 }

 /// Rename this location, keeping its existing `extension` by default.
 /// - parameter newName: The new name to give the location.
 /// - parameter keepExtension: Whether the location's `extension` should
 ///   remain unmodified (default: `true`).
 /// - throws: `PathError` if the item couldn't be renamed.
 func rename(to newName: String, keepExtension: Bool = true) throws {
  guard let parent else {
   throw PathError(path: self.path, type: Self.type, reason: .cannotRenameRoot)
  }

  var newName = newName

  if keepExtension {
   self.extension.map {
    newName = newName.appendingSuffixIfNeeded(".\($0)")
   }
  }

  try storage.move(
   to: parent.path + newName,
   errorReasonProvider: PathErrorReason.renameFailed
  )
 }

 /// Move this location to a new parent folder
 /// - parameter newParent: The folder to move this item to.
 /// - throws: `PathError` if the location couldn't be moved.
 func move(to newParent: Folder) throws {
  try storage.move(
   to: newParent.path + self.name,
   errorReasonProvider: PathErrorReason.moveFailed
  )
 }

 /// Copy the contents of this location to a given folder
 /// - parameter newParent: The folder to copy this item to.
 /// - throws: `PathError` if the location couldn't be copied.
 /// - returns: The new, copied location.
 @discardableResult
 func copy(to folder: Folder) throws -> Self {
  let path = folder.path + self.name
  try storage.copy(to: path)
  return try Self(path: path)
 }

 /// Delete this location. It will be permanently deleted. Use with caution.
 /// - throws: `PathError` if the item couldn't be deleted.
 func delete() throws {
  try storage.delete()
 }

 /// Assign a new `FileManager` to manage this location. Typically only used
 /// for testing, or when building custom file systems. Returns a new instance,
 /// doensn't modify the instance this is called on.
 /// - parameter manager: The new file manager that should manage this location.
 /// - throws: `PathError` if the change couldn't be completed.
 func managedBy(_ manager: FileManager) throws -> Self {
  try Self(storage: Storage(
   path: self.path,
   fileManager: manager
  ))
 }
}

extension Optional: ExpressibleByUnicodeScalarLiteral
 where Wrapped: PathRepresentable {}

extension Optional: ExpressibleByExtendedGraphemeClusterLiteral
 where Wrapped: PathRepresentable {}

extension Optional: ExpressibleByStringLiteral
 where Wrapped: PathRepresentable {
 public init(stringLiteral: String) {
  self = try? Wrapped(path: stringLiteral)
 }
}

// MARK: - Storage

/// Type used to store information about a given file system location. You don't
/// interact with this type as part of the public API, instead you use the APIs
/// exposed by `PathRepresentable`, `File`, and `Folder`.
public final class Storage<Path: PathRepresentable> {
 fileprivate private(set) var path: String
 let fileManager: FileManager

 fileprivate init(path: String, fileManager: FileManager) throws {
  self.path = path
  self.fileManager = fileManager
  try self.validatePath()
 }

 private func validatePath() throws {
  switch Path.type {
  case .file:
   guard !self.path.isEmpty else {
    throw PathError(path: self.path, type: Path.type, reason: .emptyFilePath)
   }
  case .folder:
   if self.path.isEmpty { self.path = self.fileManager.currentDirectoryPath }
   if !self.path.hasSuffix("/") { self.path += "/" }
  }

  if self.path.hasPrefix("~") {
   let homePath = ProcessInfo.processInfo.environment["HOME"]!
   self.path = homePath + self.path.dropFirst()
  }

  while let parentReferenceRange = path.range(of: "../") {
   let folderPath = String(path[..<parentReferenceRange.lowerBound])
   let parentPath = makeParentPath(for: folderPath) ?? "/"

   guard self.fileManager.locationExists(at: parentPath, type: .folder) else {
    throw PathError(path: parentPath, type: Path.type, reason: .missing)
   }

   self.path.replaceSubrange(..<parentReferenceRange.upperBound, with: parentPath)
  }

  guard self.fileManager.locationExists(at: self.path, type: Path.type) else {
   throw PathError(path: self.path, type: Path.type, reason: .missing)
  }
 }
}

extension Storage {
 var attributes: [FileAttributeKey: Any] {
  (try? self.fileManager.attributesOfItem(atPath: self.path)) ?? [:]
 }

 func makeParentPath(for path: String) -> String? {
  guard path != "/" else { return nil }
  let url = URL(fileURLWithPath: path)
  let components = url.pathComponents.dropFirst().dropLast()
  guard !components.isEmpty else { return "/" }
  return "/" + components.joined(separator: "/") + "/"
 }

 func move(to newPath: String,
           errorReasonProvider: (Error) -> PathErrorReason) throws {
  do {
   try self.fileManager.moveItem(atPath: self.path, toPath: newPath)

   switch Path.type {
   case .file:
    self.path = newPath
   case .folder:
    self.path = newPath.appendingSuffixIfNeeded("/")
   }
  } catch {
   throw PathError(
    path: self.path, type: Path.type, reason: errorReasonProvider(error)
   )
  }
 }

 func copy(to newPath: String) throws {
  do {
   try self.fileManager.copyItem(atPath: self.path, toPath: newPath)
  } catch {
   throw PathError(path: self.path, type: Path.type, reason: .copyFailed(error))
  }
 }

 func delete() throws {
  do {
   try self.fileManager.removeItem(atPath: self.path)
  } catch {
   throw PathError(
    path: self.path, type: Path.type, reason: .deleteFailed(error)
   )
  }
 }
}

private extension Storage where Path == Folder {
 func makeChildSequence<T: PathRepresentable>() -> Folder.ChildSequence<T> {
  Folder.ChildSequence(
   folder: Folder(storage: self),
   fileManager: self.fileManager,
   isRecursive: false,
   includeHidden: false
  )
 }

 func subfolder(at folderPath: String) throws -> Folder {
  let folderPath = self.path + folderPath.removingPrefix("/")
  let storage = try Storage(path: folderPath, fileManager: fileManager)
  return Folder(storage: storage)
 }

 func file(at filePath: String) throws -> File {
  let filePath = self.path + filePath.removingPrefix("/")
  let storage = try Storage<File>(path: filePath, fileManager: fileManager)
  return File(storage: storage)
 }

 func createSubfolder(at folderPath: String) throws -> Folder {
  let folderPath = self.path + folderPath.removingPrefix("/")

  guard folderPath != self.path else {
   throw WriteError(path: folderPath, type: Path.type, reason: .emptyPath)
  }

  do {
   try self.fileManager.createDirectory(
    atPath: folderPath,
    withIntermediateDirectories: true
   )

   let storage = try Storage(path: folderPath, fileManager: fileManager)
   return Folder(storage: storage)
  } catch {
   throw WriteError(path: folderPath, type: Path.type, reason: .folderCreationFailed(error))
  }
 }

 func createFile(at filePath: String, contents: Data?) throws -> File {
  let filePath = self.path + filePath.removingPrefix("/")

  guard let parentPath = makeParentPath(for: filePath) else {
   throw WriteError(path: filePath, type: Path.type, reason: .emptyPath)
  }

  if parentPath != self.path {
   do {
    try self.fileManager.createDirectory(
     atPath: parentPath,
     withIntermediateDirectories: true
    )
   } catch {
    throw WriteError(path: parentPath, type: Path.type, reason: .folderCreationFailed(error))
   }
  }

  guard self.fileManager.createFile(atPath: filePath, contents: contents),
        let storage = try? Storage<File>(path: filePath, fileManager: fileManager) else {
   throw WriteError(path: filePath, type: Path.type, reason: .fileCreationFailed)
  }

  return File(storage: storage)
 }
}

// MARK: - Files

/// Type that represents a file on disk. You can either reference an existing
/// file by initializing an instance with a `path`, or you can create new files
/// using the various `createFile...` APIs available on `Folder`.
public struct File: PathRepresentable {
 public let storage: Storage<File>

 public init(storage: Storage<File>) {
  self.storage = storage
 }
}

public extension File {
 static var type: PathType {
  .file
 }

 var size: UInt64 {
  if let fileSize = storage.attributes[.size] as? UInt64 {
   return fileSize
  } else {
   fatalError("couldn't lookup file size attribute under attributes")
  }
 }

 func merge(into newParent: Folder) throws {
  try self.storage.move(
   to: newParent.path + self.name,
   errorReasonProvider: PathErrorReason.moveFailed
  )
 }

 /// Write a new set of binary data into the file, replacing its current contents.
 /// - parameter data: The binary data to write.
 /// - throws: `WriteError` in case the operation couldn't be completed.
 func write(_ data: Data) throws {
  do {
   try data.write(to: url)
  } catch {
   throw WriteError(path: path, type: Self.type, reason: .writeFailed(error))
  }
 }

 /// Write a new string into the file, replacing its current contents.
 /// - parameter string: The string to write.
 /// - parameter encoding: The encoding of the string (default: `UTF8`).
 /// - throws: `WriteError` in case the operation couldn't be completed.
 func write(_ string: String, encoding: String.Encoding = .utf8) throws {
  guard let data = string.data(using: encoding) else {
   throw WriteError(path: path, type: Self.type, reason: .stringEncodingFailed(string))
  }

  return try self.write(data)
 }

 /// Append a set of binary data to the file's existing contents.
 /// - parameter data: The binary data to append.
 /// - throws: `WriteError` in case the operation couldn't be completed.
 func append(_ data: Data) throws {
  do {
   let handle = try FileHandle(forWritingTo: url)
   handle.seekToEndOfFile()
   handle.write(data)
   handle.closeFile()
  } catch {
   throw WriteError(path: path, type: Self.type, reason: .writeFailed(error))
  }
 }

 /// Append a string to the file's existing contents.
 /// - parameter string: The string to append.
 /// - parameter encoding: The encoding of the string (default: `UTF8`).
 /// - throws: `WriteError` in case the operation couldn't be completed.
 func append(_ string: String, encoding: String.Encoding = .utf8) throws {
  guard let data = string.data(using: encoding) else {
   throw WriteError(path: path, type: Self.type, reason: .stringEncodingFailed(string))
  }

  return try self.append(data)
 }

 /// Read the contents of the file as binary data.
 /// - throws: `ReadError` if the file couldn't be read.
 func read() throws -> Data {
  do { return try Data(contentsOf: url) }
  catch { throw ReadError(path: path, type: Self.type, reason: .readFailed(error)) }
 }

 /// Read the contents of the file as a string.
 /// - parameter encoding: The encoding to decode the file's data using (default: `UTF8`).
 /// - throws: `ReadError` if the file couldn't be read, or if a string couldn't
 ///   be decoded from the file's contents.
 func readAsString(encodedAs encoding: String.Encoding = .utf8) throws -> String {
  guard let string = try String(data: read(), encoding: encoding) else {
   throw ReadError(path: path, type: Self.type, reason: .stringDecodingFailed)
  }

  return string
 }

 /// Read the contents of the file as an integer.
 /// - throws: `ReadError` if the file couldn't be read, or if the file's
 ///   contents couldn't be converted into an integer.
 func readAsInt() throws -> Int {
  let string = try readAsString()

  guard let int = Int(string) else {
   throw ReadError(path: path, type: Self.type, reason: .notAnInt(string))
  }

  return int
 }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

public extension PathRepresentable {
 /// Open the file.
 func open() {
  NSWorkspace.shared.openFile(self.path)
 }

 /// Open the file with a specific application.
 func open(with app: String?) {
  if let app { NSWorkspace.shared.openFile(self.path, withApplication: app) }
  else { NSWorkspace.shared.openFile(self.path) }
 }
}

#endif

public extension PathRepresentable {
 var isSymbolicLink: Bool {
  storage.attributes[.type] as? FileAttributeType == .typeSymbolicLink
 }

 func isSymbolicLinkThrowing() throws -> Bool {
  let attributes = try FileManager.default.attributesOfItem(atPath: self.path)
  return attributes[.type] as? FileAttributeType == .typeSymbolicLink
 }

 func expandingPathThrowing() throws -> Self {
  guard try self.isSymbolicLinkThrowing() else { return self }
  return try Self(
   path: URL(fileURLWithPath: self.path).resolvingSymlinksInPath().path
  )
 }

 var expandingPath: Self {
  guard self.isSymbolicLink else { return self }
  do {
   return try Self(
    path: URL(fileURLWithPath: self.path).resolvingSymlinksInPath().path
   )
  } catch { fatalError("couldn't expand link at for \(self)") }
 }
}

// MARK: - Folders

/// Type that represents a folder on disk. You can either reference an existing
/// folder by initializing an instance with a `path`, or you can create new
/// subfolders using this type's various `createSubfolder...` APIs.
public struct Folder: PathRepresentable {
 public let storage: Storage<Folder>

 public init(storage: Storage<Folder>) {
  self.storage = storage
 }
}

public extension Folder {
 /// A sequence of child locations contained within a given folder.
 /// You obtain an instance of this type by accessing either `files`
 /// or `subfolders` on a `Folder` instance.
 struct ChildSequence<Child: PathRepresentable>: Sequence {
  fileprivate let folder: Folder
  fileprivate let fileManager: FileManager
  fileprivate var isRecursive: Bool
  fileprivate var includeHidden: Bool

  public func makeIterator() -> ChildIterator<Child> {
   ChildIterator(
    folder: self.folder,
    fileManager: self.fileManager,
    isRecursive: self.isRecursive,
    includeHidden: self.includeHidden,
    reverseTopLevelTraversal: false
   )
  }
 }

 /// The type of iterator used by `ChildSequence`. You don't interact
 /// with this type directly. See `ChildSequence` for more information.
 struct ChildIterator<Child: PathRepresentable>: IteratorProtocol {
  private let folder: Folder
  private let fileManager: FileManager
  private let isRecursive: Bool
  private let includeHidden: Bool
  private let reverseTopLevelTraversal: Bool
  private lazy var itemNames = loadItemNames()
  private var index = 0
  private var nestedIterators = [ChildIterator<Child>]()

  fileprivate init(folder: Folder,
                   fileManager: FileManager,
                   isRecursive: Bool,
                   includeHidden: Bool,
                   reverseTopLevelTraversal: Bool) {
   self.folder = folder
   self.fileManager = fileManager
   self.isRecursive = isRecursive
   self.includeHidden = includeHidden
   self.reverseTopLevelTraversal = reverseTopLevelTraversal
  }

  public mutating func next() -> Child? {
   guard self.index < self.itemNames.count else {
    guard var nested = nestedIterators.first else {
     return nil
    }

    guard let child = nested.next() else {
     self.nestedIterators.removeFirst()
     return self.next()
    }

    self.nestedIterators[0] = nested
    return child
   }

   let name = self.itemNames[self.index]
   self.index += 1

   if !self.includeHidden {
    guard !name.hasPrefix(".") else { return self.next() }
   }

   let childPath = self.folder.path + name.removingPrefix("/")
   let childStorage = try? Storage<Child>(path: childPath, fileManager: self.fileManager)
   let child = childStorage.map(Child.init)

   if self.isRecursive {
    let childFolder = (child as? Folder) ?? (try? Folder(
     storage: Storage(path: childPath, fileManager: self.fileManager)
    ))

    if let childFolder {
     let nested = ChildIterator(
      folder: childFolder,
      fileManager: fileManager,
      isRecursive: true,
      includeHidden: includeHidden,
      reverseTopLevelTraversal: false
     )

     self.nestedIterators.append(nested)
    }
   }

   return child ?? self.next()
  }

  private mutating func loadItemNames() -> [String] {
   let contents = try? self.fileManager.contentsOfDirectory(atPath: self.folder.path)
   let names = contents?.sorted() ?? []
   return self.reverseTopLevelTraversal ? names.reversed() : names
  }
 }
}

extension Folder.ChildSequence: CustomStringConvertible {
 public var description: String {
  lazy.map(\.description).joined(separator: "\n")
 }
}

public extension Folder.ChildSequence {
 /// Return a new instance of this sequence that'll traverse the folder's
 /// contents recursively, in a breadth-first manner. Complexity: `O(1)`.
 var recursive: Folder.ChildSequence<Child> {
  var sequence = self
  sequence.isRecursive = true
  return sequence
 }

 /// Return a new instance of this sequence that'll include all hidden
 /// (dot) files when traversing the folder's contents. Complexity: `O(1)`.
 var includingHidden: Folder.ChildSequence<Child> {
  var sequence = self
  sequence.includeHidden = true
  return sequence
 }

 /// Count the number of locations contained within this sequence.
 /// Complexity: `O(N)`.
 func count() -> Int {
  reduce(0) { count, _ in count + 1 }
 }

 /// Gather the names of all of the locations contained within this sequence.
 /// Complexity: `O(N)`.
 func names() -> [String] {
  map(\.name)
 }

 /// Return the last location contained within this sequence.
 /// Complexity: `O(N)`.
 func last() -> Child? {
  var iterator = Iterator(
   folder: folder,
   fileManager: fileManager,
   isRecursive: isRecursive,
   includeHidden: includeHidden,
   reverseTopLevelTraversal: !isRecursive
  )

  guard isRecursive else { return iterator.next() }

  var child: Child?

  while let nextChild = iterator.next() {
   child = nextChild
  }

  return child
 }

 /// Return the first location contained within this sequence.
 /// Complexity: `O(1)`.
 var first: Child? {
  var iterator = makeIterator()
  return iterator.next()
 }

 /// Move all locations within this sequence to a new parent folder.
 /// - parameter folder: The folder to move all locations to.
 /// - throws: `PathError` if the move couldn't be completed.
 func move(to folder: Folder) throws {
  try forEach { try $0.move(to: folder) }
 }

 /// Delete all of the locations within this sequence. All items will
 /// be permanently deleted. Use with caution.
 /// - throws: `PathError` if an item couldn't be deleted. Note that
 ///   all items deleted up to that point won't be recovered.
 func delete() throws {
  try forEach { try $0.delete() }
 }
}

public extension Folder {
 static var type: PathType {
  .folder
 }

 /// The folder that the program is currently operating in.
 static var current: Folder {
  try! Folder(path: "")
 }

 /// The root folder of the file system.
 static var root: Folder {
  try! Folder(path: "/")
 }

 /// The current user's Home folder.
 static var home: Folder {
  try! Folder(path: "~")
 }

 /// The system's temporary folder.
 static var temporary: Folder {
  try! Folder(path: NSTemporaryDirectory())
 }

 /// A sequence containing all of this folder's subfolders. Initially
 /// non-recursive, use `recursive` on the returned sequence to change that.
 var subfolders: ChildSequence<Folder> {
  self.storage.makeChildSequence()
 }

 /// A sequence containing all of this folder's files. Initially
 /// non-recursive, use `recursive` on the returned sequence to change that.
 var files: ChildSequence<File> {
  self.storage.makeChildSequence()
 }

 /// Return a subfolder at a given path within this folder.
 /// - parameter path: A relative path within this folder.
 /// - throws: `PathError` if the subfolder couldn't be found.
 func subfolder(at path: String) throws -> Folder {
  try self.storage.subfolder(at: path)
 }

 /// Return a subfolder with a given name.
 /// - parameter name: The name of the subfolder to return.
 /// - throws: `PathError` if the subfolder couldn't be found.
 func subfolder(named name: String) throws -> Folder {
  try self.storage.subfolder(at: name)
 }

 /// Return whether this folder contains a subfolder at a given path.
 /// - parameter path: The relative path of the subfolder to look for.
 func containsSubfolder(at path: String) -> Bool {
  (try? self.subfolder(at: path)) != nil
 }

 /// Return whether this folder contains a subfolder with a given name.
 /// - parameter name: The name of the subfolder to look for.
 func containsSubfolder(named name: String) -> Bool {
  (try? self.subfolder(named: name)) != nil
 }

 /// Create a new subfolder at a given path within this folder. In case
 /// the intermediate folders between this folder and the new one don't
 /// exist, those will be created as well. This method throws an error
 /// if a folder already exists at the given path.
 /// - parameter path: The relative path of the subfolder to create.
 /// - throws: `WriteError` if the operation couldn't be completed.
 @discardableResult
 func createSubfolder(at path: String) throws -> Folder {
  try self.storage.createSubfolder(at: path)
 }

 /// Create a new subfolder with a given name. This method throws an error
 /// if a subfolder with the given name already exists.
 /// - parameter name: The name of the subfolder to create.
 /// - throws: `WriteError` if the operation couldn't be completed.
 @discardableResult
 func createSubfolder(named name: String) throws -> Folder {
  try self.storage.createSubfolder(at: name)
 }

 /// Create a new subfolder at a given path within this folder. In case
 /// the intermediate folders between this folder and the new one don't
 /// exist, those will be created as well. If a folder already exists at
 /// the given path, then it will be returned without modification.
 /// - parameter path: The relative path of the subfolder.
 /// - throws: `WriteError` if a new folder couldn't be created.
 @discardableResult
 func createSubfolderIfNeeded(at path: String) throws -> Folder {
  try (try? self.subfolder(at: path)) ?? self.createSubfolder(at: path)
 }

 /// Create a new subfolder with a given name. If a subfolder with the given
 /// name already exists, then it will be returned without modification.
 /// - parameter name: The name of the subfolder.
 /// - throws: `WriteError` if a new folder couldn't be created.
 @discardableResult
 func createSubfolderIfNeeded(withName name: String) throws -> Folder {
  try (try? self.subfolder(named: name)) ?? self.createSubfolder(named: name)
 }

 func set() {
  self.storage.fileManager.changeCurrentDirectoryPath(self.path)
 }

 /// Return a file at a given path within this folder.
 /// - parameter path: A relative path within this folder.
 /// - throws: `PathError` if the file couldn't be found.
 func file(at path: String) throws -> File {
  try self.storage.file(at: path)
 }

 /// Return a file within this folder with a given name.
 /// - parameter name: The name of the file to return.
 /// - throws: `PathError` if the file couldn't be found.
 func file(named name: String) throws -> File {
  try self.storage.file(at: name)
 }

 /// Return whether this folder contains a file at a given path.
 /// - parameter path: The relative path of the file to look for.
 func containsFile(at path: String) -> Bool {
  (try? self.file(at: path)) != nil
 }

 /// Return whether this folder contains a file with a given name.
 /// - parameter name: The name of the file to look for.
 func containsFile(named name: String) -> Bool {
  (try? self.file(named: name)) != nil
 }

 /// Create a new file at a given path within this folder. In case
 /// the intermediate folders between this folder and the new file don't
 /// exist, those will be created as well. This method throws an error
 /// if a file already exists at the given path.
 /// - parameter path: The relative path of the file to create.
 /// - parameter contents: The initial `Data` that the file should contain.
 /// - throws: `WriteError` if the operation couldn't be completed.
 @discardableResult
 func createFile(at path: String, contents: Data? = nil) throws -> File {
  try self.storage.createFile(at: path, contents: contents)
 }

 /// Create a new file with a given name. This method throws an error
 /// if a file with the given name already exists.
 /// - parameter name: The name of the file to create.
 /// - parameter contents: The initial `Data` that the file should contain.
 /// - throws: `WriteError` if the operation couldn't be completed.
 @discardableResult
 func createFile(named fileName: String, contents: Data? = nil) throws -> File {
  try self.storage.createFile(at: fileName, contents: contents)
 }

 /// Create a new file at a given path within this folder. In case
 /// the intermediate folders between this folder and the new file don't
 /// exist, those will be created as well. If a file already exists at
 /// the given path, then it will be returned without modification.
 /// - parameter path: The relative path of the file.
 /// - parameter contents: The initial `Data` that any newly created file
 ///   should contain. Will only be evaluated if needed.
 /// - throws: `WriteError` if a new file couldn't be created.
 @discardableResult
 func createFileIfNeeded(at path: String,
                         contents: @autoclosure () -> Data? = nil) throws -> File {
  try (try? self.file(at: path)) ?? self.createFile(at: path, contents: contents())
 }

 /// Create a new file with a given name. If a file with the given
 /// name already exists, then it will be returned without modification.
 /// - parameter name: The name of the file.
 /// - parameter contents: The initial `Data` that any newly created file
 ///   should contain. Will only be evaluated if needed.
 /// - throws: `WriteError` if a new file couldn't be created.
 @discardableResult
 func createFileIfNeeded(withName name: String,
                         contents: @autoclosure () -> Data? = nil) throws -> File {
  try (try? self.file(named: name)) ?? self.createFile(named: name, contents: contents())
 }

 @discardableResult
 func overwrite(at path: String,
                contents: @autoclosure () -> Data? = nil) throws -> File {
  if let other = try? self.file(at: path) { try other.delete() }
  return try self.createFile(at: path, contents: contents())
 }

 /// Return whether this folder contains a given location as a direct child.
 /// - parameter location: The location to find.
 func contains<T: PathRepresentable>(_ location: T) -> Bool {
  switch T.type {
  case .file: return self.containsFile(named: location.name)
  case .folder: return self.containsSubfolder(named: location.name)
  }
 }

 /// Move the contents of this folder to a new parent
 /// - parameter folder: The new parent folder to move this folder's contents to.
 /// - parameter includeHidden: Whether hidden files should be included (default: `false`).
 /// - throws: `PathError` if the operation couldn't be completed.
 func moveContents(to folder: Folder, includeHidden: Bool = false) throws {
  var files = files
  files.includeHidden = includeHidden
  try files.move(to: folder)

  var folders = self.subfolders
  folders.includeHidden = includeHidden
  try folders.move(to: folder)
 }

 /// Empty this folder, permanently deleting all of its contents. Use with caution.
 /// - parameter includeHidden: Whether hidden files should also be deleted (default: `false`).
 /// - throws: `PathError` if the operation couldn't be completed.
 func empty(includingHidden includeHidden: Bool = false) throws {
  var files = files
  files.includeHidden = includeHidden
  try files.delete()

  var folders = self.subfolders
  folders.includeHidden = includeHidden
  try folders.delete()
 }

 func isEmpty(includingHidden includeHidden: Bool = false) -> Bool {
  var files = files
  files.includeHidden = includeHidden

  if files.first != nil {
   return false
  }

  var folders = self.subfolders
  folders.includeHidden = includeHidden
  return folders.first == nil
 }
}

#if os(iOS) || os(tvOS) || os(macOS)
public extension Folder {
 /// Resolve a folder that matches a search path within a given domain.
 /// - parameter searchPath: The directory path to search for.
 /// - parameter domain: The domain to search in.
 /// - parameter fileManager: Which file manager to search using.
 /// - throws: `PathError` if no folder could be resolved.
 static func matching(
  _ searchPath: FileManager.SearchPathDirectory,
  in domain: FileManager.SearchPathDomainMask = .userDomainMask,
  resolvedBy fileManager: FileManager = .default
 ) throws -> Folder {
  let urls = fileManager.urls(for: searchPath, in: domain)

  guard let match = urls.first else {
   throw PathError(
    path: "", type: Self.type,
    reason: .unresolvedSearchPath(searchPath, domain: domain)
   )
  }

  return try Folder(storage: Storage(
   path: match.relativePath,
   fileManager: fileManager
  ))
 }

 /// The current user's Documents folder
 static var documents: Folder? {
  try? .matching(.documentDirectory)
 }

 /// The current user's Library folder
 static var library: Folder? {
  try? .matching(.libraryDirectory)
 }
}
#endif

// MARK: - Errors

/// Error type thrown by all of Files' throwing APIs.
public struct PathsError<Reason>: CustomStringConvertible, LocalizedError {
 /// The absolute path that the error occured at.
 public var path: String
 public var type: PathType
 /// The reason that the error occured.
 public var reason: Reason

 public var description: String { "\(self.reason) \(self.type) \(self.path)" }
 public var errorDescription: String? { description }

 /// Initialize an instance with a path and a reason.
 /// - parameter path: The absolute path that the error occured at.
 /// - parameter reason: The reason that the error occured.
 public init(path: String, type: PathType, reason: Reason) {
  self.path = path
  self.type = type
  self.reason = reason
 }
}

/// Enum listing reasons that a location manipulation could fail.
public enum PathErrorReason {
 /// The location couldn't be found.
 case missing
 /// An empty path was given when refering to a file.
 case emptyFilePath
 /// The user attempted to rename the file system's root folder.
 case cannotRenameRoot
 /// A rename operation failed with an underlying system error.
 case renameFailed(Error)
 /// A move operation failed with an underlying system error.
 case moveFailed(Error)
 /// A copy operation failed with an underlying system error.
 case copyFailed(Error)
 /// A delete operation failed with an underlying system error.
 case deleteFailed(Error)
 /// A search path couldn't be resolved within a given domain.
 case unresolvedSearchPath(
  FileManager.SearchPathDirectory,
  domain: FileManager.SearchPathDomainMask
 )
}

/// Enum listing reasons that a write operation could fail.
public enum WriteErrorReason {
 /// An empty path was given when writing or creating a location.
 case emptyPath
 /// A folder couldn't be created because of an underlying system error.
 case folderCreationFailed(Error)
 /// A file couldn't be created.
 case fileCreationFailed
 /// A file couldn't be written to because of an underlying system error.
 case writeFailed(Error)
 /// Failed to encode a string into binary data.
 case stringEncodingFailed(String)
}

/// Enum listing reasons that a read operation could fail.
public enum ReadErrorReason {
 /// A file couldn't be read because of an underlying system error.
 case readFailed(Error)
 /// Failed to decode a given set of data into a string.
 case stringDecodingFailed
 /// Encountered a string that doesn't contain an integer.
 case notAnInt(String)
}

/// Error thrown by location operations - such as find, move, copy and delete.
public typealias PathError = PathsError<PathErrorReason>
/// Error thrown by write operations - such as file/folder creation.
public typealias WriteError = PathsError<WriteErrorReason>
/// Error thrown by read operations - such as when reading a file's contents.
public typealias ReadError = PathsError<ReadErrorReason>

// MARK: - Private system extensions

private extension FileManager {
 func locationExists(at path: String, type: PathType) -> Bool {
  var isFolder: ObjCBool = false

  guard fileExists(atPath: path, isDirectory: &isFolder) else {
   return false
  }

  switch type {
  case .file: return !isFolder.boolValue
  case .folder: return isFolder.boolValue
  }
 }
}

private extension String {
 func removingPrefix(_ prefix: String) -> String {
  guard hasPrefix(prefix) else { return self }
  return String(dropFirst(prefix.count))
 }

 func removingSuffix(_ suffix: String) -> String {
  guard hasSuffix(suffix) else { return self }
  return String(dropLast(suffix.count))
 }

 func appendingSuffixIfNeeded(_ suffix: String) -> String {
  guard !hasSuffix(suffix) else { return self }
  return appending(suffix)
 }
}
