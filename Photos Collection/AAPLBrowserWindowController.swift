//
//  AAPLBrowserWindowController.swift
//  CocoaSlideCollection
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/21.
//
//
/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample‚Äôs licensing information

    Abstract:
    This is the browser window controller declaration.
*/

import Cocoa

var thumbMaxSize : Int! = Int()

@objc enum SlideLayoutKind: Int {

    case wrapped
}

/*
Each browser window is managed by a AAPLBrowserWindowController, which
serves as its CollectionView's dataSource and delegate.  (The
CollectionView's dataSource and delegate outlets are wired up in
BrowserWindow.xib, so there is no need to set these properties in code.)
*/
@objc(AAPLBrowserWindowController)
class AAPLBrowserWindowController : NSWindowController, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {
    // Model
    private var rootURL: URL!                                         // URL of the folder whose image files the browser is displaying
    var imageCollection: AAPLImageCollection?                   // the ImageFiles we found in the folder, which we can access as a flat list or grouped by AAPLTag
    
    //MARK: Outlets
    // Views
    @IBOutlet weak var imageCollectionView: NSCollectionView!  // a CollectionView that displays items ("slides") representing the image files
    @IBOutlet weak var statusTextField: NSTextField!           // a TextField that shows informative status
    @IBOutlet weak var mySlider: NSSlider!
    
    // UI State
    private var _layoutKind: SlideLayoutKind = .wrapped                             // what kind of layout to use, per the above SlideLayoutKind enumeration
                                           // YES if our imageCollectionView should show its items grouped by tag, with header and footer views (usable with Wrapped layout only)
    private var autoUpdateResponseSuspended: Bool = false                       // YES when we want to suppress our usual automatic KVO response to assets coming and going
    private var indexPathsOfItemsBeingDragged: Set<IndexPath> = []    // when our imageCollectionView is the source for a drag operation, this array of NSIndexPaths identifies the items that are being dragged within or out of it
    
    

    
    private let selectionIndexPathsKey = "selectionIndexPaths"
   
    
    // Initializes a browser window that's pointed at the given folder URL.
    convenience init(rootURL newRootURL: URL) {
        self.init(windowNibName: NSNib.Name(rawValue: "BrowserWindow"))
        rootURL = newRootURL
        
        _layoutKind = SlideLayoutKind.wrapped
        
        // Create an AAPLImageCollection for browsing our assigned folder.
        imageCollection = AAPLImageCollection(rootURL: rootURL)
        
        /*
        Watch for changes in the imageCollection's imageFiles list.
        Whenever a new AAPLImageFile is added or removed,
        Key-Value Observing (KVO) will send us an
        -observeValueForKeyPath:ofObject:change:context: message, which we
        can respond to as needed to update the set of slides that we
        display.
        */
        self.startObservingImageCollection()
        
    }
    
    // This important method, which is invoked after the AAPLBrowserWindowController has finished loading its BrowserWindow.nib file, is where we perform some important setup of our NSCollectionView.
    override func windowDidLoad() {
        
        thumbMaxSize = mySlider.integerValue
        // Set the window's title to the name of the folder we're browsing.
        self.window?.title = rootURL.lastPathComponent
        print("rootURL=\(rootURL)")
        
        // Set imageCollectionView.collectionViewLayout to match our desired layoutKind.
        self.updateLayout()
        
        // Watch for changes to the CollectionView's selection, just so we can update our status display.
        imageCollectionView.addObserver(self, forKeyPath: selectionIndexPathsKey, options: [], context: nil)
        
        // Start scanning our assigned folder for image files.
        imageCollection?.startOrRestartFileTreeScan()
        
        // Configure our CollectionView for drag-and-drop.
        self.registerForCollectionViewDragAndDrop()
    }
    
    private func registerForCollectionViewDragAndDrop() {
        
        // Register for the dropped object types we can accept.
        imageCollectionView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: kUTTypeFileURL as String), NSPasteboard.PasteboardType(rawValue: kUTTypeItem as String)])
        
        // Enable dragging items from our CollectionView to other applications.
        imageCollectionView.setDraggingSourceOperationMask(.every, forLocal: false)
        
        // Enable dragging items within and into our CollectionView.
        imageCollectionView.setDraggingSourceOperationMask(.every, forLocal: true)
    }
    
    
    //MARK: SLIDER RESIZE
    @IBAction func resizeItems(_ sender: Any) {
        thumbMaxSize = mySlider.integerValue
        let activeItems = imageCollectionView.indexPathsForVisibleItems()
        synchronized(self) {
            imageCollectionView.reloadItems(at: activeItems)
        }
        //imageCollectionView.collectionViewLayout?.invalidateLayout()
    }
    
    //MARK: Properties
    @objc dynamic var layoutKind: SlideLayoutKind {
        get {
            return _layoutKind
        }
        
        set(newLayoutKind) {
            if _layoutKind != newLayoutKind {
                if newLayoutKind != .wrapped  {
                    NSAnimationContext.current.duration = 0.0 // Suppress animation.
                   
                }
                _layoutKind = newLayoutKind
                self.updateLayout()
            }
        }
    }
    
    private func updateLayout() {
        
        var layout: NSCollectionViewLayout? = nil
        switch layoutKind {
      
        case .wrapped: layout = AAPLWrappedLayout()
  
        }
        if let layout = layout {
            if NSAnimationContext.current.duration > 0.0 {
                NSAnimationContext.current.duration = 0.5
                imageCollectionView.animator().collectionViewLayout = layout
            } else {
                imageCollectionView.collectionViewLayout = layout
            }
        }
    }
    
    private func suspendAutoUpdateResponse() {
        autoUpdateResponseSuspended = true
    }
    
    private func resumeAutoUpdateResponse() {
        autoUpdateResponseSuspended = false
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object as AnyObject? === imageCollection && !autoUpdateResponseSuspended {
            
            /*
            We're being notified that our imageCollection's contents have
            changed, and we haven't disabled our auto-update response, so we
            want to inform our imageCollectionView of the exact change that
            just took place.  Identify the change by examining the "object",
            "keyPath", and "change" dictionary we've been given, then handle
            the change accordingly.  For insertion or removal of items, the
            "change" dictionary will give us a set of "indexes" that specify
            what was added or removed from the parent "object" (which might be
            the imageCollection itself, or one of its AAPLTags).  Part of what
            we may need to do is map these indices to corresponding
            (section,item) NSIndexPaths.
            */
            
            let kind = change![NSKeyValueChangeKey.kindKey]! as! UInt
            if kind == NSKeyValueChange.insertion.rawValue || kind == NSKeyValueChange.removal.rawValue {
                
                let indexes = change![NSKeyValueChangeKey.indexesKey]! as! IndexSet
                var indexPaths: Set<IndexPath> = []
                if keyPath == imageFilesKey {
                    if object as AnyObject? === imageCollection {
                        
                        // Our imageCollection's "imageFiles" array changed.
                        indexes.forEach {itemIndex in
                            indexPaths.insert(IndexPath(item: itemIndex, section: 0))
                        }
                        
                    } 
                    
                    // Notify our imageCollectionView of the change.
                    if kind == NSKeyValueChange.insertion.rawValue {
                        self.handleImageFilesInsertedAtIndexPaths(indexPaths)
                    } else {
                        self.handleImageFilesRemovedAtIndexPaths(indexPaths)
                    }
                    
                }
                
            } else {
                // For NSKeyValueChangeSetting, we just reload everything.
                self.imageCollectionView.reloadData()
            }
        }
    }
    
    //MARK: Actions
    // Invoked by the "File" -> "Refresh" menu item.
    func refresh(_: AnyObject) {
        /*
        Ask our imageCollection to check for new, changed, and removed asset
        files.  This AAPLBrowserWindowController will be automatically notified
        of changes to the imageCollection via KVO, since we registered to
        observe the imageCollection's contents.
        */
        imageCollection?.startOrRestartFileTreeScan()
    }
    
    private func imageFileAtIndexPath(_ indexPath: IndexPath) -> AAPLImageFile? {
        
            return imageCollection?.imageFiles[indexPath.item]
        
    }
    
    
    //MARK: NSCollectionViewDataSource Methods
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        
            return 1
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        
            // Return the number of ImageFiles in the collection (treated as a single, flat list).
            return imageCollection?.imageFiles.count ?? 0
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        // Message back to the collectionView, asking it to make a @"Slide" item associated with the given item indexPath.  The collectionView will first check whether an NSNib or item Class has been registered with that name (via -registerNib:forItemWithIdentifier: or -registerClass:forItemWithIdentifier:).  Failing that, the collectionView will search for a .nib file named "Slide".  Since our .nib file is named "Slide.nib", no registration is necessary.
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Slide"), for: indexPath)
        let imageFile = self.imageFileAtIndexPath(indexPath)
        item.representedObject = imageFile
        
        return item
    }
    
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        let identifier: String? = nil
        let view = collectionView.makeSupplementaryView(ofKind: kind, withIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier ?? ""), for: indexPath)
        
        return view
    }
    
    
    //MARK: NSCollectionViewDelegateFlowLayout Methods
    
    // Implementing this delegate method tells a NSCollectionViewFlowLayout (such as our AAPLWrappedLayout) what size to make a "Header" supplementary view.  (The actual size will be clipped to the CollectionView's width.)

    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: CGFloat(mySlider.floatValue), height: CGFloat(mySlider.floatValue))
    }
    
    
    //MARK: NSCollectionViewDelegate Drag-and-Drop Methods
    
    
    /*******************/
    /* Dragging Source */
    /*******************/
    
    /*
    1. When a CollectionView wants to begin a drag operation for some of its
    items, it first sends this message to its delegate.  The delegate may return
    YES to allow the proposed drag to begin, or NO to prevent it.  We want to
    allow the user to drag any and all items in the CollectionView, so we
    unconditionally return YES here.  If you wish, however, you can return NO
    under certain circumstances, to prevent the items specified by "indexPaths"
    from being dragged.
    */
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }
    
    /*
    2. If the above method allows the drag to begin, the CollectionView will invoke
    this method once per item to be dragged, to request a pasteboard writer for
    the item's underlying model object.  Some kinds of model objects (for
    example, NSURL) are themselves suitable pasteboard writers.
    */
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        let imageFile = self.imageFileAtIndexPath(indexPath)!
        return imageFile.url.absoluteURL as NSPasteboardWriting? // An NSURL can be a pasteboard writer, but must be returned as an absolute URL.
    }
    
    /*
    3. After obtaining a pasteboard writer for each item to be dragged, the
    CollectionView will invoke this method to notify you that the drag is
    beginning.  You aren't required to implement this delegate method, but it
    can provide a useful hook for one particular start-of-drag action you might
    want to perform: saving a copy fo the passed the indexPaths as an indication
    to yourself that the drag began in this CollectionView, which will prove
    useful if the same CollectionView ends up being the drop destination.
    */
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
        
        /*
        Remember the indexPaths we're dragging, in case we end up being the drag
        destination too.  Knowing that a drop originated from this
        CollectionView will enable us to handle it more efficiently, and with
        a "move items" operation instead of a
        */
        indexPathsOfItemsBeingDragged = indexPaths
    }
    
    /*
    If this CollectionView ends up also being the dragging destination, we'll
    receive the "Dragging Destination" messages as implemented below, before
    the dragging session ends.
    */
    
    /*
    6. Whether the drag is accepted, or the drag operation is cancelled, the
    CollectionView always sends this mesage to conclude the drag session.  It's
    a good place to perform any necessary cleanup, such as clearing the
    "indexPathsOfItemsBeingDragged" we saved in the
    -collectionView:draggingSession:willBeginAtPoint:forItemsAtIndexPaths:
    method, above.
    */
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation) {
        
        // Clear the dragging indexPaths we saved earlier.
        indexPathsOfItemsBeingDragged = []
    }
    
    
    /************************/
     /* Dragging Destination */
     /************************/
     
     /*
     4. When the user drags something around a CollectionView (whether the dragging
     source is the same CollectionView or some other view, potentially in a
     different process), the CollectionView will repeatedly invoke this method to
     propose dropping the dragging items at various places within within itself.
     (If the user mouses out of the CollectionView, the CollectionView stops
     sending this message.  If the user mouses back into the CollectionView, the
     CollectionView starts sending this messsage again.)  You return an
     NSDragOperation mask to specify what kinds of drag operations should be
     allowed for the proposed destination.  You may also alter the
     proposedDropOperation and proposedDropIndexPath through the provided
     pointers, if desired.
     */
    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        
            return NSDragOperation.copy
        
    }
    
    /*
    5. If the user commits the proposed drop operation (by releasing the mouse
    button), the CollectionView invokes this method to instruct its delegate to
    make the proposed edit.  Your implementation has the important
    responsibility of (1) modifying your model as proposed, and then
    (2) notifying the CollectionView of the edits.  Return YES if you completed
    the drop successfully, NO if you could not complete the drop.
    */
    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        
        var result = false
     
        /*
        Suspend our usual KVO response to ImageCollection changes.  We want to
        notify the CollectionView of updates manually, so we can animate a
        "move" instead of a "delete" and "insert".
        */
        self.suspendAutoUpdateResponse()
        
        // Is our own imageCollectionView the dragging source?
        if !indexPathsOfItemsBeingDragged.isEmpty {
            
            // Yes, existing items are being dragged within our imageCollectionView.
            
            let indexPathsOfItemsBeingDraggedSorted = indexPathsOfItemsBeingDragged.sorted{$0.compare($1) == .orderedAscending}
                /*
                Walk forward through fromItemIndex values > toItemIndex, to keep
                our "from" and "to" indexes valid as we go, moving items one at
                a time.
                */
                var toItemIndex = indexPath.item
                for fromIndexPath in indexPathsOfItemsBeingDraggedSorted {
                    let fromItemIndex = fromIndexPath.item
                    if fromItemIndex > toItemIndex {
                        
                        /*
                        For each step: First, modify our model.
                        */
                        imageCollection?.moveImageFileFromIndex(fromItemIndex, toIndex: toItemIndex)
                        
                        /*
                        Next, notify the CollectionView of the change we just
                        made to our model.
                        */
                        imageCollectionView.animator().moveItem(at: IndexPath(item: fromItemIndex, section: indexPath.section), to: IndexPath(item: toItemIndex, section: indexPath.section))
                        
                        // Advance to maintain moved items in their original order.
                        toItemIndex += 1
                    }
                }
                
                /*
                Walk backward through fromItemIndex values < toItemIndex, to
                keep our "from" and "to" indexes valid as we go, moving items
                one at a time.
                */
                var adjustedToItemIndex = indexPath.item - 1
                for fromIndexPath in indexPathsOfItemsBeingDraggedSorted.lazy.reversed() {
                    let fromItemIndex = fromIndexPath.item
                    if fromItemIndex < adjustedToItemIndex {
                        
                        /*
                        For each step: First, modify our model.
                        */
                        imageCollection?.moveImageFileFromIndex(fromItemIndex, toIndex: adjustedToItemIndex)
                        
                        /*
                        Next, notify the CollectionView of the change we just
                        made to our model.
                        */
                        let adjustedToIndexPath = IndexPath(item: adjustedToItemIndex, section: indexPath.section)
                        imageCollectionView.animator().moveItem(at: IndexPath(item: fromItemIndex, section: indexPath.section), to: adjustedToIndexPath)
                        
                        // Retreat to maintain moved items in their original order.
                        adjustedToItemIndex -= 1
                    }
                }
                
                // We did it!
                result = true
            
            
        } else {
            
            // Items are being dragged from elsewhere into our CollectionView.
            
            /*
            Examine the items to be dropped, as provided by the draggingInfo
            object.  Accumulate the URLs among them into a "droppedObjects"
            array.
            */
            var droppedObjects: [URL] = []
            draggingInfo.enumerateDraggingItems(options: [], for: collectionView, classes: [NSURL.self], searchOptions: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true]) {draggingItem, idx, stop in
                
                if let url = draggingItem.item as? URL {
                    droppedObjects.append(url)
                }
            }
            
            /*
            For each dropped URL:
            
            1. Create a corresponding AAPLImageFile.
            2. Insert the AAPLImageFile at the designated point in our
            imageCollection.
            3. Notify our CollectionView of the insertion.
            
            We check first whether the colleciton already contains an ImageFile
            with the given URL, and disallow duplicates.
            */
            let insertionIndex = indexPath.item
            var errors: [NSError] = []
            for url in droppedObjects {
                var imageFile = imageCollection?.imageFileForURL(url)
                if imageFile == nil {
                    
                    /*
                    Copy the image file from the source URL into our
                    imageCollection's folder.
                    */
                    guard let targetURL = imageCollection?.rootURL?.appendingPathComponent(url.lastPathComponent, isDirectory: false) else {
                        fatalError()
                    }
                    do {
                        try FileManager.default.copyItem(at: url, to: targetURL)
                        
                        /*
                        Now create and insert an ImageFile that references the
                        targetURL we copied to.
                        */
                        imageFile = AAPLImageFile(URL: targetURL)
                        /*
                        For each item: First, modify our model.
                        */
                        imageCollection?.insertImageFile(imageFile!, atIndex: insertionIndex)
                        
                        /*
                        Next, notify the CollectionView of the change we just
                        made to our model.
                        */
                        collectionView.animator().insertItems(at: [indexPath])
                        
                        // We succeeded in accepting at least one item.
                        result = true
                    } catch let error as NSError {
                        /*
                        Copy failed.  Remember the error, and notify the user of
                        just the first failure, instead of pestering them about
                        each of potentially several failures.
                        */
                        errors.append(error)
                    }
                }
            }
            
            if !errors.isEmpty {
                imageCollectionView.presentError(errors[0], modalFor: imageCollectionView.window!, delegate: nil, didPresent: nil, contextInfo: nil)
            }
        }
        
        // Resume normal KVO handling.
        self.resumeAutoUpdateResponse()
        
        // Return indicating success or failure.
        return result
    }
    
    
    //MARK: Teardown
    
    @objc func windowWillClose(_ notification: Notification) {
        imageCollection?.stopWatchingFolder() // Break retain cycle, allowing teardown.
        self.stopObservingImageCollection()
        imageCollectionView.removeObserver(self, forKeyPath: selectionIndexPathsKey)
    }
    
  
    
    private func startObservingImageCollection() {
        /*
        Sign up for Key-Value Observing (KVO) notifications, that will tell us
        when the content of our imageCollection changes.  If we are showing
        its ImageFiles grouped by tag, we want to observe the imageCollection's
        "tags" array, and the "imageFiles" array of each AAPLTag.  If we are
        showing our imageCollection's ImageFiles without grouping, we instead
        want to simply observe the imageCollection's "imageFiles" array.
        
        Whenever a change occurs, KVO will send us an
        -observeValueForKeyPath:ofObject:change:context: message, which we
        can respond to as needed to update the set of slides that we
        display.
        */
       
            imageCollection?.addObserver(self, forKeyPath: imageFilesKey, options: [], context: nil)
        
    }
    
    private func stopObservingImageCollection() {
       
            imageCollection?.removeObserver(self, forKeyPath: imageFilesKey)
        
    }
    
    private func handleImageFilesInsertedAtIndexPaths(_ indexPaths: Set<IndexPath>) {
        NSAnimationContext.current.duration = 0.25
        self.imageCollectionView.animator().insertItems(at: indexPaths)
    }
    
    private func handleImageFilesRemovedAtIndexPaths(_ indexPaths: Set<IndexPath>) {
        NSAnimationContext.current.duration = 0.25
        self.imageCollectionView.animator().deleteItems(at: indexPaths)
    }
    
    private func handleTagsInsertedInCollectionAtIndexes(_ indexes: IndexSet) {
        NSAnimationContext.current.duration = 0.25
        self.imageCollectionView.animator().insertSections(indexes)
    }
    
    private func handleTagsRemovedFromCollectionAtIndexes(_ indexes: IndexSet) {
        NSAnimationContext.current.duration = 0.25
        self.imageCollectionView?.animator().deleteSections(indexes)
    }
    
}

private func StringFromCollectionViewDropOperation(_ dropOperation: NSCollectionView.DropOperation) -> String {
    switch dropOperation {
    case .before:
        return "before";
        
    case .on:
        return "on";
        
    }
}

private func StringFromCollectionViewIndexPath(_ indexPath: IndexPath?) -> String {
    if let indexPath = indexPath , indexPath.count == 2 {
        return "(\(indexPath.section),\(indexPath.item))"
    } else {
        return "(nil)"
    }
}
