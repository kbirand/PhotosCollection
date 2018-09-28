//
//  AAPLImageCollection.swift
//  CocoaSlideCollection
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/24.
//
//
/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample‚Äôs licensing information

    Abstract:
    This is the "ImageCollection" class declaration.
*/

import Cocoa

let imageFilesKey = "imageFiles"

// An AAPLImageCollection encapsulates a list of AAPLImageFile objects, together with a rootURL that identifies the folder (if any) where we found them.  It also has a list of associated Tags, each of which can return the list of ImageFiles to which it's applied.
@objc(AAPLImageCollection)
class AAPLImageCollection: NSObject {
    
    //MARK: Properties
    
    private(set) var rootURL: URL?
    @objc private(set) dynamic var imageFiles: [AAPLImageFile] = []
    
    private var fileTreeWatcherThread: AAPLFileTreeWatcherThread?
    private var fileTreeScanQueue: OperationQueue
    
    private var imageFilesByURL: [URL: AAPLImageFile] = [:]

    
    init(rootURL newRootURL: URL) {
        
        rootURL = newRootURL
        let queue = OperationQueue()
        queue.name = "AAPLImageCollection File Tree Scan Queue"
        fileTreeScanQueue = queue
        
        /*
        Start watching the folder for changes.  Note that the "self" in this
        block creates a retain cycle.  To break it, we must
        -stopWatchingFolder when closing a browser window.
        */
        super.init()
        fileTreeWatcherThread = AAPLFileTreeWatcherThread(path: newRootURL.path) {
            
            // When we detect a change in the folder, scan it to find out what changed.
            self.startOrRestartFileTreeScan()
        }
        fileTreeWatcherThread!.start()
    }
    
    
    //MARK: Querying the List of ImageFiles
    
    func imageFileForURL(_ imageFileURL: URL) -> AAPLImageFile? {
        return imageFilesByURL[imageFileURL]
    }
    
    
    //MARK: Modifying the List of ImageFiles
    
    func addImageFile(_ imageFile: AAPLImageFile) {
        self.insertImageFile(imageFile, atIndex: imageFiles.count)
    }
    
    func insertImageFile(_ imageFile: AAPLImageFile, atIndex index: Int) {
        
        // Add and update tags, based on the imageFile's tagNames.
       
        
        
        
        // Insert the imageFile into our "imageFiles" array (in a KVO-compliant way).
        self.mutableArrayValue(forKey: imageFilesKey).insert(imageFile, at: index)
        
        // Add the imageFile into our "imageFilesByURL" dictionary.
        imageFilesByURL[imageFile.url] = imageFile
    }
    
    func removeImageFile(_ imageFile: AAPLImageFile) {
        
        // Remove the imageFile from our "imageFiles" array (in a KVO-compliant way).
        self.mutableArrayValue(forKey: imageFilesKey).remove(imageFile)
        
        // Remove the imageFile from our "imageFilesByURL" dictionary.
        imageFilesByURL.removeValue(forKey: imageFile.url)
        
        // Remove the imageFile from the "imageFiles" arrays of its AAPLTags (if any).
     
    }
    
    func removeImageFileAtIndex(_ index: Int) {
        let imageFile = imageFiles[index]
        self.removeImageFile(imageFile)
    }
    
    func moveImageFileFromIndex(_ fromIndex: Int, toIndex: Int) {
        let imageFilesCount = imageFiles.count
        assert(fromIndex < imageFilesCount)
        assert(toIndex < imageFilesCount)  //###
        let imageFile = imageFiles[fromIndex]
        self.removeImageFileAtIndex(fromIndex)
        self.insertImageFile(imageFile, atIndex: (toIndex <= fromIndex) ? toIndex : (toIndex - 1))
    }
    
    

    
    
    //MARK: Finding Image Files
    
    func startOrRestartFileTreeScan() {
        synchronized(fileTreeScanQueue) {
            // Cancel any pending file tree scan operations.
            self.stopFileTreeScan()
            
            // Enqueue a new file tree scan operation.
            fileTreeScanQueue.addOperation {
                
                /*
                Enumerate all of the image files in our given rootURL.  As we
                go, identify three groups of image files:
                
                (1) files that are in the catalog, but have since changed (the
                file's modification date is later than its last-cached date)
                
                (2) files that exist on disk but are not yet in the catalog
                (presumably the file was added and we should create an
                ImageFile instance for it)
                
                (3) files that exist in the ImageCollection but not in the
                folder (presumably the file was deleted and we should remove
                the corresponding ImageFile instance)
                */
                var filesToProcess = self.imageFiles
                var filesChanged: [AAPLImageFile] = []
                var urlsAdded: [URL] = []
                var filesRemoved: [AAPLImageFile] = []
                
                let directoryEnumerator = FileManager.default.enumerator(at: self.rootURL!, includingPropertiesForKeys: [URLResourceKey.isRegularFileKey, URLResourceKey.typeIdentifierKey, URLResourceKey.contentModificationDateKey], options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants]) {url, error in
                    NSLog("directoryEnumerator error: \(error)")
                    return true
                    }!
                for url in directoryEnumerator {
                    let url = url as! URL
                    block: do {
                        let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .typeIdentifierKey])
                        let isRegularFile = resource.isRegularFile!
                        guard isRegularFile else {break block}
                        let fileType = resource.typeIdentifier!
                        guard UTTypeConformsTo(fileType as CFString, "public.image" as CFString) else {break block}
                        
                        // Look for a corresponding entry in the catalog.
                        if let imageFile = self.imageFileForURL(url) {
                            // Check whether file has changed.
                            do {
                                let resource = try url.resourceValues(forKeys: [.contentModificationDateKey])
                                let modificationDate = resource.contentModificationDate!
                                if modificationDate.compare(imageFile.dateLastUpdated!) == .orderedDescending {
                                    filesChanged.append(imageFile)
                                }
                            } catch _ {}
                            filesToProcess = filesToProcess.filter{$0 != imageFile}
                        } else {
                            // File was added.
                            urlsAdded.append(url)
                        }
                    } catch _ {}
                }
                
                // Check for images in the catalog for which no corresponding file was found.
                filesRemoved.append(contentsOf: filesToProcess)
                filesToProcess = []
                
                /*
                Perform our ImageCollection modifications on the main thread, so
                that corresponding KVO notifications and CollectionView updates will
                also happen on the main thread.
                */
                OperationQueue.main.addOperation {
                    
                    // Remove ImageFiles for files we knew about that have disappeared.
                    for imageFile in filesRemoved {
                        self.removeImageFile(imageFile)
                    }
                    
                    // Add ImageFiles for files we've newly discovered.
                    for imageFileURL in urlsAdded {
                        let imageFile = AAPLImageFile(URL: imageFileURL)
                        self.addImageFile(imageFile)
                    }
                }
            }
        }
    }
    
    func stopFileTreeScan() {
        synchronized(fileTreeScanQueue) {
            fileTreeScanQueue.cancelAllOperations()
        }
    }
    
    func stopWatchingFolder() {
        fileTreeWatcherThread?.detachChangeHandler()
        fileTreeWatcherThread?.cancel()
        fileTreeWatcherThread = nil
    }
    
    
    //MARK: Teardown
    
    deinit {
        self.stopWatchingFolder()
    }
    
}
