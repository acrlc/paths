import Paths

@available(macOS 10.15, *)
public actor FileObserver {
 public typealias Result = (Projection, Set<Projection.Change>, File)
 let interval: UInt64
 let file: File
 var task: Task<Result?, Error>?

 /// Initialize a file observer with a default interval of 0.78 seconds
 /// - Parameters:
 ///  - file: The file to observe
 ///  - interval: The update interval in nanoseconds, default 0.78 seconds
 public init(_ file: File, interval: UInt64? = nil) {
  self.file = file
  self.interval = interval ?? 777_777_777
 }

 public func callAsFunction(
  _ handler: @escaping (Result) async throws -> ()
 ) async throws {
  // TODO: replace file property if moved by bookmarking
  // or stop observing if deleted
  let task = Task<Result?, Error>.detached {
   var projection = Projection(self.file)
   var prior = Prior(self.file.parent!)
   
   while true {
    let folder = prior.path
    let file = projection.path

    if let modified = prior.modificationDate,
       let previous = folder.modificationDate {
     if modified > previous {
      prior.modificationDate = modified
      return (projection, [], file)
     }
    } else {
     break
    }

    if let modified = file.modificationDate,
       let previous = projection.modificationDate {
     if modified > previous {
      // TODO: check if path was moved
      if let date = file.modificationDate {
       projection.modificationDate = date
       return (projection, [.modificationDate], file)
      } else {
       break
      }
     }
    }

    try await Task.sleep(nanoseconds: self.interval)
   }
   return nil
  }

  self.task = task

  if let value = try await task.value {
   try await handler(value)
   try await callAsFunction(handler)
  } else {
   self.task?.cancel()
  }
 }

 deinit { task?.cancel() }
}

@available(macOS 10.15, *)
public extension FileObserver {
 struct Prior: @unchecked Sendable {
  public let path: Folder
  public var modificationDate: Date?
  public init(_ file: Folder) {
   self.path = file
   self.modificationDate = path.modificationDate
  }
 }

 struct Projection: @unchecked Sendable {
  public enum Change: Hashable {
   case modificationDate
  }

  public let path: File
  public var modificationDate: Date?
  public init(_ file: File) {
   self.path = file
   self.modificationDate = path.modificationDate
  }
 }
}
