import Foundation

#if os(WASI) || os(Windows) || os(Linux)
import enum Crypto.Insecure
import FoundationNetworking

// https://medium.com/hoursofoperation/use-async-urlsession-with-server-side-swift-67821a64fa91
enum URLSessionAsyncErrors: Error {
 case invalidUrlResponse, missingResponseData
}

extension URLSession {
 func data(from url: URL) async throws -> (Data, URLResponse) {
  try await withCheckedThrowingContinuation { continuation in
   let task = self.dataTask(with: url) { data, response, error in
    if let error {
     continuation.resume(throwing: error)
     return
    }
    guard let response = response as? HTTPURLResponse else {
     continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
     return
    }
    guard let data else {
     continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
     return
    }
    continuation.resume(returning: (data, response))
   }
   task.resume()
  }
 }

 func data(for request: URLRequest) async throws -> (Data, URLResponse) {
  try await withCheckedThrowingContinuation { continuation in
   let task = self.dataTask(with: request) { data, response, error in
    if let error {
     continuation.resume(throwing: error)
     return
    }
    guard let response = response as? HTTPURLResponse else {
     continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
     return
    }
    guard let data else {
     continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
     return
    }
    continuation.resume(returning: (data, response))
   }
   task.resume()
  }
 }
}

private extension Data {
 init(url: URL, session: URLSession = .shared) async throws {
  self = try await session.data(from: url).0
 }

 init(for request: URLRequest, session: URLSession = .shared) async throws {
  self = try await session.data(for: request).0
 }
}

@available(macOS 12, iOS 15, *)
public extension File {
 /// Initialize a temporary file from a URL
 init(url: URL, session: URLSession = .shared) async throws {
  let temp = Folder.temporary
  let data = try await Data(url: url, session: session)
  // TODO: base64 encode before hashing
  let hash =
   Insecure.MD5.hash(data: Data(url.absoluteString.utf8))
    .compactMap { String(format: "%02x", $0) }
    .joined()
  // TODO: test overwrite
  self = try temp.createFile(at: hash, contents: data)
 }

 init(for request: URLRequest, session: URLSession = .shared) async throws {
  assert(request.url != nil)
  let data = try await Data(for: request, session: session)
  let temp = Folder.temporary
  // TODO: base64 encode before hashing
  let hash =
   Insecure.MD5
    .hash(data: Data(request.url.unsafelyUnwrapped.absoluteString.utf8))
    .compactMap { String(format: "%02x", $0) }
    .joined()
  // TODO: test overwrite
  self = try temp.createFile(at: hash, contents: data)
 }
}

@available(macOS 12, iOS 15, *)
public extension Folder {
 func file(
  from url: URL, session: URLSession = .shared, at path: String
 ) async throws -> File {
  let data = try await Data(url: url, session: session)
  return try self.createFile(at: path, contents: data)
 }

 func file(
  for request: URLRequest, session: URLSession = .shared, at path: String
 ) async throws -> File {
  let data = try await Data(for: request, session: session)
  return try self.createFile(at: path, contents: data)
 }
}

#elseif os(iOS) || os(macOS)
import enum CryptoKit.Insecure

@available(macOS 12, iOS 15, *)
private extension Data {
 init(
  url: URL, session: URLSession = .shared,
  delegate: URLSessionTaskDelegate? = nil
 ) async throws {
  self = try await session.data(from: url, delegate: delegate).0
 }

 init(
  for request: URLRequest, session: URLSession = .shared,
  delegate: URLSessionTaskDelegate? = nil
 ) async throws {
  self = try await session.data(for: request, delegate: delegate).0
 }
}

@available(macOS 12, iOS 15, *)
public extension File {
 /// Initialize a temporary file from a URL
 init(
  url: URL,
  session: URLSession = .shared,
  delegate: URLSessionTaskDelegate? = nil
 ) async throws {
  let temp = Folder.temporary
  let data = try await Data(url: url, session: session, delegate: delegate)
  // TODO: base64 encode before hashing
  let hash =
   Insecure.MD5.hash(data: Data(url.absoluteString.utf8))
    .compactMap { String(format: "%02x", $0) }
    .joined()
  // TODO: test overwrite
  self = try temp.createFile(at: hash, contents: data)
 }

 init(
  for request: URLRequest,
  session: URLSession = .shared,
  delegate: URLSessionTaskDelegate? = nil
 ) async throws {
  assert(request.url != nil)
  let temp = Folder.temporary
  let data = try await Data(for: request, session: session, delegate: delegate)
  // TODO: base64 encode before hashing
  let hash =
   Insecure.MD5
    .hash(data: Data(request.url.unsafelyUnwrapped.absoluteString.utf8))
    .compactMap { String(format: "%02x", $0) }
    .joined()
  // TODO: test overwrite
  self = try temp.createFile(at: hash, contents: data)
 }
}

@available(macOS 12, iOS 15, *)
public extension Folder {
 func file(
  from url: URL,
  session: URLSession = .shared,
  delegate: URLSessionTaskDelegate? = nil,
  at path: String
 ) async throws -> File {
  let data = try await Data(url: url, session: session, delegate: delegate)
  return try self.createFile(at: path, contents: data)
 }

 func file(
  for request: URLRequest,
  session: URLSession = .shared,
  delegate: URLSessionTaskDelegate? = nil,
  at path: String
 ) async throws -> File {
  let data = try await Data(for: request, session: session, delegate: delegate)
  return try self.createFile(at: path, contents: data)
 }
}
#endif
