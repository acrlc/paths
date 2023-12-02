# Paths
An extension of [files](https://www.github.com/JohnSundell/Files), modified to add attributes and functions such as `open` and `overwrite`. Paths is useful for creating single use apps, such as command line apps that can be used with [swift-shell](https://www.github.com/codeAcrylic/swift-shell) and [command](https://www.github.com/codeAcrylic/command).
## Examples
Iterate over the files contained in a folder:
```swift
for file in try Folder(path: "MyFolder").files {
 print(file.name)
}
```
Rename all files contained in a folder:
```swift
try Folder(path: "MyFolder").files.enumerated().forEach { (index, file) in
 try file.rename(to: file.nameWithoutExtension + "\(index)")
}
```
Recursively iterate over all folders in a tree:
```swift
Folder.home.subfolders.recursive.forEach { folder in
 print("Name : \(folder.name), parent: \(folder.parent)")
}
```
Create, write and delete files and folders:
```swift
let folder = try Folder(path: "/users/john/folder")
let file = try folder.createFile(named: "file.json")
try file.write("{\"hello\": \"world\"}")
try file.delete()
try folder.delete()
```
Move all files in a folder to another:
```swift
let originFolder = try Folder(path: "/users/john/folderA")
let targetFolder = try Folder(path: "/users/john/folderB")
try originFolder.files.move(to: targetFolder)
```
Easy access to system folders:
```swift
Folder.current
Folder.root
Folder.library
Folder.temporary
Folder.home
Folder.documents
```

