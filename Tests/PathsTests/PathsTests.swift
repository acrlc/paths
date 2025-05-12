/**
 *  Files
 *
 *  Copyright (c) 2017-2019 John Sundell. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation
import Paths
import XCTest

class PathsTests: XCTestCase {
 private var folder: Folder!

 // MARK: - XCTestCase

 override func setUp() {
  super.setUp()
  self.folder = try! Folder.home.createSubfolderIfNeeded(withName: ".filesTest")
  try! self.folder.empty()
 }

 override func tearDown() {
  try? self.folder.delete()
  super.tearDown()
 }

 // MARK: - Tests

 func testCreatingAndDeletingFile() {
  self.performTest {
   // Verify that the file doesn't exist
   XCTAssertFalse(self.folder.containsFile(named: "test.txt"))

   // Create a file and verify its properties
   let file = try folder.createFile(named: "test.txt")
   XCTAssertEqual(file.name, "test.txt")
   XCTAssertEqual(file.path, self.folder.path + "test.txt")
   XCTAssertEqual(file.extension, "txt")
   XCTAssertEqual(file.nameExcludingExtension, "test")
   try XCTAssertEqual(file.read(), Data())

   // You should now be able to access the file using its path and through the parent
   _ = try File(path: file.path)
   XCTAssertTrue(self.folder.containsFile(named: "test.txt"))

   try file.delete()

   // Attempting to read the file should now throw an error
   try self.assert(file.read(), throwsErrorOfType: ReadError.self)

   // Attempting to create a File instance with the path should now also fail
   try self.assert(File(path: file.path), throwsErrorOfType: PathError.self)
  }
 }

 func testCreatingFileAtPath() {
  self.performTest {
   let path = "a/b/c.txt"

   XCTAssertFalse(self.folder.containsFile(at: path))
   try self.folder.createFile(at: path, contents: Data("Hello".utf8))

   XCTAssertTrue(self.folder.containsFile(at: path))
   XCTAssertTrue(self.folder.containsSubfolder(named: "a"))
   XCTAssertTrue(self.folder.containsSubfolder(at: "a/b"))

   let file = try folder.createFileIfNeeded(at: path)
   XCTAssertEqual(try file.readAsString(), "Hello")
  }
 }

 func testCreatingFileIfNeededAtPath() {
  self.performTest {
   let path = "a/b/c.txt"

   XCTAssertFalse(self.folder.containsFile(at: path))
   var file = try folder.createFileIfNeeded(at: path, contents: Data("Hello".utf8))

   XCTAssertTrue(self.folder.containsFile(at: path))
   XCTAssertTrue(self.folder.containsSubfolder(named: "a"))
   XCTAssertTrue(self.folder.containsSubfolder(at: "a/b"))

   file = try self.folder.createFileIfNeeded(at: path, contents: Data())
   XCTAssertEqual(try file.readAsString(), "Hello")
  }
 }

 func testDroppingLeadingSlashWhenCreatingFileAtPath() {
  self.performTest {
   let path = "/a/b/c.txt"

   XCTAssertFalse(self.folder.containsFile(at: path))
   try self.folder.createFile(at: path, contents: Data("Hello".utf8))

   XCTAssertTrue(self.folder.containsFile(at: path))
   XCTAssertTrue(self.folder.containsSubfolder(named: "a"))
   XCTAssertTrue(self.folder.containsSubfolder(at: "/a/b"))

   let file = try folder.createFileIfNeeded(at: path)
   XCTAssertEqual(try file.readAsString(), "Hello")
  }
 }

 func testCreatingAndDeletingFolder() {
  self.performTest {
   // Verify that the folder doesn't exist
   XCTAssertFalse(self.folder.containsSubfolder(named: "folder"))

   // Create a folder and verify its properties
   let subfolder = try folder.createSubfolder(named: "folder")
   XCTAssertEqual(subfolder.name, "folder")
   XCTAssertEqual(subfolder.path, self.folder.path + "folder/")

   // You should now be able to access the folder using its path and through the parent
   _ = try Folder(path: subfolder.path)
   XCTAssertTrue(self.folder.containsSubfolder(named: "folder"))

   // Put a file in the folder
   let file = try subfolder.createFile(named: "file")
   try XCTAssertEqual(file.read(), Data())

   try subfolder.delete()

   // Attempting to create a Folder instance with the path should now fail
   try self.assert(Folder(path: subfolder.path), throwsErrorOfType: PathError.self)

   // The file contained in the folder should now also be deleted
   try self.assert(file.read(), throwsErrorOfType: ReadError.self)
  }
 }

 func testCreatingSubfolderAtPath() {
  self.performTest {
   let path = "a/b/c"

   XCTAssertFalse(self.folder.containsSubfolder(at: path))
   try self.folder.createSubfolder(at: path).createFile(named: "d.txt")

   XCTAssertTrue(self.folder.containsSubfolder(at: path))
   XCTAssertTrue(self.folder.containsSubfolder(named: "a"))
   XCTAssertTrue(self.folder.containsSubfolder(at: "a/b"))
   XCTAssertTrue(self.folder.containsFile(at: "a/b/c/d.txt"))

   let subfolder = try folder.createSubfolderIfNeeded(at: path)
   XCTAssertEqual(subfolder.files.names(), ["d.txt"])
  }
 }

 func testDroppingLeadingSlashWhenCreatingSubfolderAtPath() {
  self.performTest {
   let path = "a/b/c"

   XCTAssertFalse(self.folder.containsSubfolder(at: path))
   try self.folder.createSubfolder(at: path).createFile(named: "d.txt")

   XCTAssertTrue(self.folder.containsSubfolder(at: path))
   XCTAssertTrue(self.folder.containsSubfolder(named: "a"))
   XCTAssertTrue(self.folder.containsSubfolder(at: "/a/b"))
   XCTAssertTrue(self.folder.containsFile(at: "/a/b/c/d.txt"))

   let subfolder = try folder.createSubfolderIfNeeded(at: path)
   XCTAssertEqual(subfolder.files.names(), ["d.txt"])
  }
 }

 func testReadingFileAsString() {
  self.performTest {
   let file = try folder.createFile(named: "string", contents: "Hello".data(using: .utf8)!)
   try XCTAssertEqual(file.readAsString(), "Hello")
  }
 }

 func testReadingFileAsInt() {
  self.performTest {
   let intFile = try folder.createFile(named: "int", contents: "\(7)".data(using: .utf8)!)
   try XCTAssertEqual(intFile.readAsInt(), 7)

   let nonIntFile = try folder.createFile(named: "nonInt", contents: "Not an int".data(using: .utf8)!)
   try self.assert(nonIntFile.readAsInt(), throwsErrorOfType: ReadError.self)
  }
 }

 func testRenamingFile() {
  self.performTest {
   let file = try folder.createFile(named: "file.json")
   try file.rename(to: "renamedFile")
   XCTAssertEqual(file.name, "renamedFile.json")
   XCTAssertEqual(file.path, self.folder.path + "renamedFile.json")
   XCTAssertEqual(file.extension, "json")

   // Now try renaming the file, replacing its extension
   try file.rename(to: "other.txt", keepExtension: false)
   XCTAssertEqual(file.name, "other.txt")
   XCTAssertEqual(file.path, self.folder.path + "other.txt")
   XCTAssertEqual(file.extension, "txt")
  }
 }

 func testRenamingFileWithNameIncludingExtension() {
  self.performTest {
   let file = try folder.createFile(named: "file.json")
   try file.rename(to: "renamedFile.json")
   XCTAssertEqual(file.name, "renamedFile.json")
   XCTAssertEqual(file.path, self.folder.path + "renamedFile.json")
   XCTAssertEqual(file.extension, "json")
  }
 }

 func testReadingFileWithRelativePath() {
  self.performTest {
   try self.folder.createFile(named: "file")

   // Make sure we're not already in the file's parent directory
   XCTAssertNotEqual(FileManager.default.currentDirectoryPath, self.folder.path)

   XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(self.folder.path))
   let file = try File(path: "file")
   try XCTAssertEqual(file.read(), Data())
  }
 }

 func testReadingFileWithTildePath() {
  self.performTest {
   try self.folder.createFile(named: "File")
   let file = try File(path: "~/.filesTest/File")
   try XCTAssertEqual(file.read(), Data())
   XCTAssertEqual(file.path, self.folder.path + "File")

   // Cleanup since we're performing a test in the actual home folder
   try file.delete()
  }
 }

 func testReadingFileFromCurrentFoldersParent() {
  self.performTest {
   let subfolder = try folder.createSubfolder(named: "folder")
   let file = try folder.createFile(named: "file")

   // Move to the subfolder
   XCTAssertNotEqual(FileManager.default.currentDirectoryPath, subfolder.path)
   XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(subfolder.path))

   try XCTAssertEqual(File(path: "../file"), file)
  }
 }

 func testReadingFileWithMultipleParentReferencesWithinPath() {
  self.performTest {
   let subfolderA = try folder.createSubfolder(named: "A")
   try self.folder.createSubfolder(named: "B")
   let subfolderC = try folder.createSubfolder(named: "C")
   let file = try subfolderC.createFile(named: "file")

   try XCTAssertEqual(File(path: subfolderA.path + "../B/../C/file"), file)
  }
 }

 func testRenamingFolder() {
  self.performTest {
   let subfolder = try folder.createSubfolder(named: "folder")
   try subfolder.rename(to: "renamedFolder")
   XCTAssertEqual(subfolder.name, "renamedFolder")
   XCTAssertEqual(subfolder.path, self.folder.path + "renamedFolder/")
  }
 }

 func testAccesingFileByPath() {
  self.performTest {
   let subfolderA = try folder.createSubfolder(named: "A")
   let subfolderB = try subfolderA.createSubfolder(named: "B")
   let file = try subfolderB.createFile(named: "C")
   try XCTAssertEqual(self.folder.file(at: "A/B/C"), file)
  }
 }

 func testAccessingSubfolderByPath() {
  self.performTest {
   let subfolderA = try folder.createSubfolder(named: "A")
   let subfolderB = try subfolderA.createSubfolder(named: "B")
   let subfolderC = try subfolderB.createSubfolder(named: "C")
   try XCTAssertEqual(self.folder.subfolder(at: "A/B/C"), subfolderC)
  }
 }

 func testEmptyingFolder() {
  self.performTest {
   try self.folder.createFile(named: "A")
   try self.folder.createFile(named: "B")
   XCTAssertEqual(self.folder.files.count(), 2)

   try self.folder.empty()
   XCTAssertEqual(self.folder.files.count(), 0)
  }
 }

 func testEmptyingFolderWithHiddenFiles() {
  self.performTest {
   let subfolder = try folder.createSubfolder(named: "folder")

   try subfolder.createFile(named: "A")
   try subfolder.createFile(named: ".B")
   XCTAssertEqual(subfolder.files.includingHidden.count(), 2)

   // Per default, hidden files should not be deleted
   try subfolder.empty()
   XCTAssertEqual(subfolder.files.includingHidden.count(), 1)

   try subfolder.empty(includingHidden: true)
   XCTAssertEqual(self.folder.files.count(), 0)
  }
 }

 func testCheckingEmptyFolders() {
  self.performTest {
   let emptySubfolder = try folder.createSubfolder(named: "1")
   XCTAssertTrue(emptySubfolder.isEmpty())

   let subfolderWithFile = try folder.createSubfolder(named: "2")
   try subfolderWithFile.createFile(named: "A")
   XCTAssertFalse(subfolderWithFile.isEmpty())

   let subfolderWithHiddenFile = try folder.createSubfolder(named: "3")
   try subfolderWithHiddenFile.createFile(named: ".B")
   XCTAssertTrue(subfolderWithHiddenFile.isEmpty())
   XCTAssertFalse(subfolderWithHiddenFile.isEmpty(includingHidden: true))

   let subfolderWithFolder = try folder.createSubfolder(named: "3")
   try subfolderWithFolder.createSubfolder(named: "4")
   XCTAssertFalse(subfolderWithFile.isEmpty())
  }
 }

 func testMovingFiles() {
  self.performTest {
   try self.folder.createFile(named: "A")
   try self.folder.createFile(named: "B")
   XCTAssertEqual(self.folder.files.count(), 2)

   let subfolder = try folder.createSubfolder(named: "folder")
   try self.folder.files.move(to: subfolder)
   try XCTAssertNotNil(subfolder.file(named: "A"))
   try XCTAssertNotNil(subfolder.file(named: "B"))
   XCTAssertEqual(self.folder.files.count(), 0)
  }
 }

 func testCopyingFiles() {
  self.performTest {
   let file = try folder.createFile(named: "A")
   try file.write("content")

   let subfolder = try folder.createSubfolder(named: "folder")
   let copiedFile = try file.copy(to: subfolder)
   try XCTAssertNotNil(self.folder.file(named: "A"))
   try XCTAssertNotNil(subfolder.file(named: "A"))
   try XCTAssertEqual(file.read(), subfolder.file(named: "A").read())
   try XCTAssertEqual(copiedFile, subfolder.file(named: "A"))
   XCTAssertEqual(self.folder.files.count(), 1)
  }
 }

 func testMovingFolders() {
  self.performTest {
   let a = try folder.createSubfolder(named: "A")
   let b = try a.createSubfolder(named: "B")
   _ = try b.createSubfolder(named: "C")

   try b.move(to: self.folder)
   XCTAssertTrue(self.folder.containsSubfolder(named: "B"))
   XCTAssertTrue(b.containsSubfolder(named: "C"))
  }
 }

 func testCopyingFolders() {
  self.performTest {
   let copyingFolder = try folder.createSubfolder(named: "A")

   let subfolder = try folder.createSubfolder(named: "folder")
   let copiedFolder = try copyingFolder.copy(to: subfolder)
   XCTAssertTrue(self.folder.containsSubfolder(named: "A"))
   XCTAssertTrue(subfolder.containsSubfolder(named: "A"))
   XCTAssertEqual(copiedFolder, try subfolder.subfolder(named: "A"))
   XCTAssertEqual(self.folder.subfolders.count(), 2)
   XCTAssertEqual(subfolder.subfolders.count(), 1)
  }
 }

 func testEnumeratingFiles() {
  self.performTest {
   try self.folder.createFile(named: "1")
   try self.folder.createFile(named: "2")
   try self.folder.createFile(named: "3")

   // Hidden files should be excluded by default
   try self.folder.createFile(named: ".hidden")

   XCTAssertEqual(self.folder.files.names().sorted(), ["1", "2", "3"])
   XCTAssertEqual(self.folder.files.count(), 3)
  }
 }

 func testEnumeratingFilesIncludingHidden() {
  self.performTest {
   let subfolder = try folder.createSubfolder(named: "folder")
   try subfolder.createFile(named: ".hidden")
   try subfolder.createFile(named: "visible")

   let files = subfolder.files.includingHidden
   XCTAssertEqual(files.names().sorted(), [".hidden", "visible"])
   XCTAssertEqual(files.count(), 2)
  }
 }

 func testEnumeratingFilesRecursively() {
  self.performTest {
   let subfolder1 = try folder.createSubfolder(named: "1")
   let subfolder2 = try folder.createSubfolder(named: "2")

   let subfolder1A = try subfolder1.createSubfolder(named: "A")
   let subfolder1B = try subfolder1.createSubfolder(named: "B")

   let subfolder2A = try subfolder2.createSubfolder(named: "A")
   let subfolder2B = try subfolder2.createSubfolder(named: "B")

   try subfolder1.createFile(named: "File1")
   try subfolder1A.createFile(named: "File1A")
   try subfolder1B.createFile(named: "File1B")
   try subfolder2.createFile(named: "File2")
   try subfolder2A.createFile(named: "File2A")
   try subfolder2B.createFile(named: "File2B")

   let expectedNames = ["File1", "File1A", "File1B", "File2", "File2A", "File2B"]
   let sequence = self.folder.files.recursive
   XCTAssertEqual(sequence.names(), expectedNames)
   XCTAssertEqual(sequence.count(), 6)
  }
 }

 func testEnumeratingSubfolders() {
  self.performTest {
   try self.folder.createSubfolder(named: "1")
   try self.folder.createSubfolder(named: "2")
   try self.folder.createSubfolder(named: "3")

   XCTAssertEqual(self.folder.subfolders.names(), ["1", "2", "3"])
   XCTAssertEqual(self.folder.subfolders.count(), 3)
  }
 }

 func testEnumeratingSubfoldersRecursively() {
  self.performTest {
   let subfolder1 = try folder.createSubfolder(named: "1")
   let subfolder2 = try folder.createSubfolder(named: "2")

   try subfolder1.createSubfolder(named: "1A")
   try subfolder1.createSubfolder(named: "1B")

   try subfolder2.createSubfolder(named: "2A")
   try subfolder2.createSubfolder(named: "2B")

   let expectedNames = ["1", "1A", "1B", "2", "2A", "2B"]
   let sequence = self.folder.subfolders.recursive
   XCTAssertEqual(sequence.names().sorted(), expectedNames)
   XCTAssertEqual(sequence.count(), 6)
  }
 }

 func testRenamingFoldersWhileEnumeratingSubfoldersRecursively() {
  self.performTest {
   let subfolder1 = try folder.createSubfolder(named: "1")
   let subfolder2 = try folder.createSubfolder(named: "2")

   try subfolder1.createSubfolder(named: "1A")
   try subfolder1.createSubfolder(named: "1B")

   try subfolder2.createSubfolder(named: "2A")
   try subfolder2.createSubfolder(named: "2B")

   let sequence = self.folder.subfolders.recursive

   for folder in sequence {
    try folder.rename(to: "Folder " + folder.name)
   }

   let expectedNames = ["Folder 1", "Folder 1A", "Folder 1B", "Folder 2", "Folder 2A", "Folder 2B"]

   XCTAssertEqual(sequence.names().sorted(), expectedNames)
   XCTAssertEqual(sequence.count(), 6)
  }
 }

 func testFirstAndLastInFileSequence() {
  self.performTest {
   try self.folder.createFile(named: "A")
   try self.folder.createFile(named: "B")
   try self.folder.createFile(named: "C")

   XCTAssertEqual(self.folder.files.first?.name, "A")
   XCTAssertEqual(self.folder.files.last()?.name, "C")
  }
 }

 func testConvertingFileSequenceToRecursive() {
  self.performTest {
   try self.folder.createFile(named: "A")
   try self.folder.createFile(named: "B")

   let subfolder = try folder.createSubfolder(named: "1")
   try subfolder.createFile(named: "1A")

   let names = self.folder.files.recursive.names()
   XCTAssertEqual(names, ["A", "B", "1A"])
  }
 }

 func testModificationDate() {
  self.performTest {
   let subfolder = try folder.createSubfolder(named: "Folder")
   XCTAssertTrue(subfolder.modificationDate.map(Calendar.current.isDateInToday) ?? false)

   let file = try folder.createFile(named: "File")
   XCTAssertTrue(file.modificationDate.map(Calendar.current.isDateInToday) ?? false)
  }
 }

 func testParent() {
  self.performTest {
   try XCTAssertEqual(self.folder.createFile(named: "test").parent, self.folder)

   let subfolder = try folder.createSubfolder(named: "subfolder")
   XCTAssertEqual(subfolder.parent, self.folder)
   try XCTAssertEqual(subfolder.createFile(named: "test").parent, subfolder)
  }
 }

 func testRootFolderParentIsNil() {
  self.performTest {
   try XCTAssertNil(Folder(path: "/").parent)
  }
 }

 func testRootSubfolderParentIsRoot() {
  self.performTest {
   let rootFolder = try Folder(path: "/")
   let subfolder = rootFolder.subfolders.first
   XCTAssertEqual(subfolder?.parent, rootFolder)
  }
 }

 func testOpeningFileWithEmptyPathThrows() {
  self.performTest {
   try self.assert(File(path: ""), throwsErrorOfType: PathError.self)
  }
 }

 func testDeletingNonExistingFileThrows() {
  self.performTest {
   let file = try folder.createFile(named: "file")
   try file.delete()
   try self.assert(file.delete(), throwsErrorOfType: PathError.self)
  }
 }

 func testWritingDataToFile() {
  self.performTest {
   let file = try folder.createFile(named: "file")
   try XCTAssertEqual(file.read(), Data())

   let data = "New content".data(using: .utf8)!
   try file.write(data)
   try XCTAssertEqual(file.read(), data)
  }
 }

 func testWritingStringToFile() {
  self.performTest {
   let file = try folder.createFile(named: "file")
   try XCTAssertEqual(file.read(), Data())

   try file.write("New content")
   try XCTAssertEqual(file.read(), "New content".data(using: .utf8))
  }
 }

 func testAppendingDataToFile() {
  self.performTest {
   let file = try folder.createFile(named: "file")
   let data = "Old content\n".data(using: .utf8)!
   try file.write(data)

   let newData = "I'm the appended content 💯\n".data(using: .utf8)!
   try file.append(newData)
   try XCTAssertEqual(file.read(), "Old content\nI'm the appended content 💯\n".data(using: .utf8))
  }
 }

 func testAppendingStringToFile() {
  self.performTest {
   let file = try folder.createFile(named: "file")
   try file.write("Old content\n")

   let newString = "I'm the appended content 💯\n"
   try file.append(newString)
   try XCTAssertEqual(file.read(), "Old content\nI'm the appended content 💯\n".data(using: .utf8))
  }
 }

 func testFileDescription() {
  self.performTest {
   let file = try folder.createFile(named: "file")
   XCTAssertEqual(file.description, self.folder.path + "file")
  }
 }

 func testFolderDescription() {
  self.performTest {
   let subfolder = try folder.createSubfolder(named: "folder")
   XCTAssertEqual(subfolder.description, self.folder.path + "folder/")
  }
 }

 func testFilesDescription() {
  self.performTest {
   let fileA = try folder.createFile(named: "fileA")
   let fileB = try folder.createFile(named: "fileB")
   XCTAssertEqual(self.folder.files.description, "\(fileA.description)\n\(fileB.description)")
  }
 }

 func testSubfoldersDescription() {
  self.performTest {
   let folderA = try folder.createSubfolder(named: "folderA")
   let folderB = try folder.createSubfolder(named: "folderB")
   XCTAssertEqual(self.folder.subfolders.description, "\(folderA.description)\n\(folderB.description)")
  }
 }

 func testMovingFolderContents() {
  self.performTest {
   let parentFolder = try folder.createSubfolder(named: "parentA")
   try parentFolder.createSubfolder(named: "folderA")
   try parentFolder.createSubfolder(named: "folderB")
   try parentFolder.createFile(named: "fileA")
   try parentFolder.createFile(named: "fileB")

   XCTAssertEqual(parentFolder.subfolders.names(), ["folderA", "folderB"])
   XCTAssertEqual(parentFolder.files.names(), ["fileA", "fileB"])

   let newParentFolder = try folder.createSubfolder(named: "parentB")
   try parentFolder.moveContents(to: newParentFolder)

   XCTAssertEqual(parentFolder.subfolders.names(), [])
   XCTAssertEqual(parentFolder.files.names(), [])
   XCTAssertEqual(newParentFolder.subfolders.names(), ["folderA", "folderB"])
   XCTAssertEqual(newParentFolder.files.names(), ["fileA", "fileB"])
  }
 }

 func testMovingFolderHiddenContents() {
  self.performTest {
   let parentFolder = try folder.createSubfolder(named: "parent")
   try parentFolder.createFile(named: ".hidden")
   try parentFolder.createSubfolder(named: ".folder")

   XCTAssertEqual(parentFolder.files.includingHidden.names(), [".hidden"])
   XCTAssertEqual(parentFolder.subfolders.includingHidden.names(), [".folder"])

   let newParentFolder = try folder.createSubfolder(named: "parentB")
   try parentFolder.moveContents(to: newParentFolder, includeHidden: true)

   XCTAssertEqual(parentFolder.files.includingHidden.names(), [])
   XCTAssertEqual(parentFolder.subfolders.includingHidden.names(), [])
   XCTAssertEqual(newParentFolder.files.includingHidden.names(), [".hidden"])
   XCTAssertEqual(newParentFolder.subfolders.includingHidden.names(), [".folder"])
  }
 }

 func testAccessingHomeFolder() {
  XCTAssertNotNil(Folder.home)
 }

 func testAccessingCurrentWorkingDirectory() {
  self.performTest {
   let folder = try Folder(path: "")
   XCTAssertEqual(FileManager.default.currentDirectoryPath + "/", folder.path)
   XCTAssertEqual(Folder.current, folder)
  }
 }

 func testNameExcludingExtensionWithLongFileName() {
  self.performTest {
   let file = try folder.createFile(named: "AVeryLongFileName.png")
   XCTAssertEqual(file.nameExcludingExtension, "AVeryLongFileName")
  }
 }

 func testNameExcludingExtensionWithoutExtension() {
  self.performTest {
   let file = try folder.createFile(named: "File")
   let subfolder = try folder.createSubfolder(named: "Subfolder")

   XCTAssertEqual(file.nameExcludingExtension, "File")
   XCTAssertEqual(subfolder.nameExcludingExtension, "Subfolder")
  }
 }

 func testRelativePaths() {
  self.performTest {
   let file = try folder.createFile(named: "FileA")
   let subfolder = try folder.createSubfolder(named: "Folder")
   let fileInSubfolder = try subfolder.createFile(named: "FileB")

   XCTAssertEqual(file.path(relativeTo: self.folder), "FileA")
   XCTAssertEqual(subfolder.path(relativeTo: self.folder), "Folder")
   XCTAssertEqual(fileInSubfolder.path(relativeTo: self.folder), "Folder/FileB")
  }
 }

 func testRelativePathIsAbsolutePathForNonParent() {
  self.performTest {
   let file = try folder.createFile(named: "FileA")
   let subfolder = try folder.createSubfolder(named: "Folder")

   XCTAssertEqual(file.path(relativeTo: subfolder), file.path)
  }
 }

 func testCreateFileIfNeeded() {
  self.performTest {
   let fileA = try folder.createFileIfNeeded(withName: "file", contents: "Hello".data(using: .utf8)!)
   let fileB = try folder.createFileIfNeeded(withName: "file", contents: "World".data(using: .utf8)!)
   try XCTAssertEqual(fileA.readAsString(), "Hello")
   try XCTAssertEqual(fileA.read(), fileB.read())
  }
 }

 func testCreateFolderIfNeeded() {
  self.performTest {
   let subfolderA = try folder.createSubfolderIfNeeded(withName: "Subfolder")
   try subfolderA.createFile(named: "file")
   let subfolderB = try folder.createSubfolderIfNeeded(withName: subfolderA.name)
   XCTAssertEqual(subfolderA, subfolderB)
   XCTAssertEqual(subfolderA.files.count(), subfolderB.files.count())
   XCTAssertEqual(subfolderA.files.first, subfolderB.files.first)
  }
 }

 func testCreateSubfolderIfNeeded() {
  self.performTest {
   let subfolderA = try folder.createSubfolderIfNeeded(withName: "folder")
   try subfolderA.createFile(named: "file")
   let subfolderB = try folder.createSubfolderIfNeeded(withName: "folder")
   XCTAssertEqual(subfolderA, subfolderB)
   XCTAssertEqual(subfolderA.files.count(), subfolderB.files.count())
   XCTAssertEqual(subfolderA.files.first, subfolderB.files.first)
  }
 }

 func testCreatingFileWithString() {
  self.performTest {
   let file = try folder.createFile(named: "file", contents: Data("Hello world".utf8))
   XCTAssertEqual(try file.readAsString(), "Hello world")
  }
 }

 #if os(macOS) || os(iOS)
 // FileManager is not open on Linux, so it's skipped here
 func testUsingCustomFileManager() {
  class FileManagerMock: FileManager {
   var noFilesExist = false

   override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
    if self.noFilesExist {
     return false
    }

    return super.fileExists(atPath: path, isDirectory: isDirectory)
   }
  }

  self.performTest {
   let fileManager = FileManagerMock()
   let subfolder = try folder.managedBy(fileManager).createSubfolder(named: UUID().uuidString)
   let file = try subfolder.createFile(named: "file")
   try XCTAssertEqual(file.read(), Data())

   // Mock that no files exist, which should call file lookups to fail
   fileManager.noFilesExist = true
   try self.assert(subfolder.file(named: "file"), throwsErrorOfType: PathError.self)
  }
 }
 #endif

 func testFolderContainsFile() {
  self.performTest {
   let subfolder = try folder.createSubfolder(named: "subfolder")
   let fileA = try subfolder.createFile(named: "A")
   XCTAssertFalse(self.folder.contains(fileA))

   let fileB = try folder.createFile(named: "B")
   XCTAssertTrue(self.folder.contains(fileB))
  }
 }

 func testFolderContainsSubfolder() {
  self.performTest {
   let subfolder = try folder.createSubfolder(named: "subfolder")
   let subfolderA = try subfolder.createSubfolder(named: "A")
   XCTAssertFalse(self.folder.contains(subfolderA))

   let subfolderB = try folder.createSubfolder(named: "B")
   XCTAssertTrue(self.folder.contains(subfolderB))
  }
 }

 func testErrorDescriptions() {
  let missingError = PathError(
   path: "/some/path", type: .file,
   reason: PathErrorReason.missing
  )

  XCTAssertEqual(missingError.description, "missing file /some/path")

  let encodingError = PathsError(
   path: "/some/path", type: .file,
   reason: WriteErrorReason.stringEncodingFailed("Hello")
  )

  XCTAssertEqual(
   encodingError.description,
   "stringEncodingFailed(\"Hello\") file /some/path"
  )
 }

 // MARK: - Utilities

 private func performTest(closure: () throws -> Void) {
  do {
   try self.folder.empty()
   try closure()
  } catch {
   XCTFail("Unexpected error thrown: \(error)")
  }
 }

 private func assert<E: Error>(_ expression: @autoclosure () throws -> some Any,
                               throwsErrorOfType expectedError: E.Type) {
  do {
   _ = try expression()
   XCTFail("Expected error to be thrown")
  } catch {
   XCTAssertTrue(error is E)
  }
 }
}

#if os(macOS)
extension PathsTests {
 func testAccessingDocumentsFolder() {
  XCTAssertNotNil(Folder.documents, "Documents folder should be available.")
 }
}
#endif

#if os(iOS) || os(tvOS) || os(macOS)
extension PathsTests {
 func testAccessingLibraryFolder() {
  XCTAssertNotNil(Folder.library, "Library folder should be available.")
 }

 func testResolvingFolderMatchingSearchPath() {
  self.performTest {
   // Real file I/O
   XCTAssertNotNil(try Folder.matching(.cachesDirectory))
   XCTAssertNotNil(try Folder.matching(.libraryDirectory))

   // Mocked file I/O
   final class FileManagerMock: FileManager {
    var target: Folder?

    override func urls(
     for directory: FileManager.SearchPathDirectory,
     in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
     self.target.map { [$0.url] } ?? []
    }
   }

   let target = try folder.createSubfolder(named: "Target")

   let fileManager = FileManagerMock()
   fileManager.target = target

   let resolved = try Folder.matching(.documentDirectory,
                                      resolvedBy: fileManager)

   XCTAssertEqual(resolved, target)
  }
 }
}
#endif
