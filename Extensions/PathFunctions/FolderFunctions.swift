@_exported import Paths

/// A processor for different kinds of folders
public struct FolderFunction {
 // TODO: Generalize paths to use the `open` function so this will work with
 // files and folders and can be extended to work based on a set of wildcards
 public let handler: (Folder) throws -> (() throws -> ())?
 // TODO: Add convenience filter to handle based on the static functions
 public init(_ handler: @escaping (Folder) throws -> (() throws -> ())?) {
  self.handler = handler
 }

 public static let swiftPackage = Self { folder in
  if let file = folder.files.first(where: { $0.name == "Package.swift" }) {
   return { file.open() }
  } else {
   return nil
  }
 }

 public static let xcodeProject = Self { folder in
  let subfolders = folder.subfolders
  if let destination =
   subfolders.first(where: { $0.extension == "xcworkspace" }) ??
   subfolders.first(where: { $0.extension == "xcodeproj" }) {
   return { destination.open() }
  } else {
   return nil
  }
 }

 public static let folder = Self { folder in { folder.open() } }
}

extension FolderFunction: CaseIterable {
 public static let allCases: [Self] = [.swiftPackage, .xcodeProject, .folder]
}
