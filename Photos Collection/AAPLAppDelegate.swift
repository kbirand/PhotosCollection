//
//  AAPLAppDelegate.swift
//  CocoaSlideCollection
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/27.
//
//
/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample‚Äôs licensing information

    Abstract:
    This is the application delegate declaration.
*/

import Cocoa

let filesArray : [String] = [
    "/Library/Desktop Pictures/Abstract Shapes.jpg",
    "/Library/Desktop Pictures/Abstract.jpg",
    "/Library/Desktop Pictures/Antelope Canyon.jpg",
    "/Library/Desktop Pictures/Bahamas Aerial.jpg",
    "/Library/Desktop Pictures/Blue Pond.jpg",
    "/Library/Desktop Pictures/Color Burst 1.jpg",
    "/Library/Desktop Pictures/Color Burst 2.jpg",
    "/Library/Desktop Pictures/Color Burst 3.jpg",
    "/Library/Desktop Pictures/Death Valley.jpg",
    "/Library/Desktop Pictures/Desert.jpg",
    "/Library/Desktop Pictures/Earth Horizon.jpg",
    "/Library/Desktop Pictures/Earth and Moon.jpg",
    "/Library/Desktop Pictures/El Capitan 2.jpg",
    "/Library/Desktop Pictures/El Capitan.jpg",
    "/Library/Desktop Pictures/Elephant.jpg",
    "/Library/Desktop Pictures/Floating Ice.jpg",
    "/Library/Desktop Pictures/Foggy Forest.jpg",
    "/Library/Desktop Pictures/Foxtail Barley.jpg",
    "/Library/Desktop Pictures/High Sierra.jpg",
    "/Library/Desktop Pictures/Ink Cloud.jpg",
    "/Library/Desktop Pictures/Lake.jpg",
    "/Library/Desktop Pictures/Lion.jpg",
    "/Library/Desktop Pictures/Milky Way.jpg",
    "/Library/Desktop Pictures/Mountain Range.jpg",
    "/Library/Desktop Pictures/Poppies.jpg",
    "/Library/Desktop Pictures/Rice Paddy.jpg",
    "/Library/Desktop Pictures/Rolling Waves.jpg",
    "/Library/Desktop Pictures/Sierra 2.jpg",
    "/Library/Desktop Pictures/Sierra.jpg",
    "/Library/Desktop Pictures/Snow.jpg",
    "/Library/Desktop Pictures/Wave.jpg",
    "/Library/Desktop Pictures/Yosemite 2.jpg",
    "/Library/Desktop Pictures/Yosemite 3.jpg",
    "/Library/Desktop Pictures/Yosemite 4.jpg",
    "/Library/Desktop Pictures/Yosemite 5.jpg",
    "/Library/Desktop Pictures/Yosemite.jpg"]

/*
The application delegate opens a browser window for
"/Library/Desktop Pictures" on launch, and handles requests to open
additional browser windows.
*/

@NSApplicationMain
@objc(AAPLAppDelegate)
class AAPLAppDelegate: NSObject, NSApplicationDelegate {

    private var browserWindowControllers: Set<AAPLBrowserWindowController> = []
    
    /*
     Given a file:// URL that points to a folder, opens a new browser window that
     displays the image files in that folder.
     */
    private func openBrowserWindowForFolderURL(_ folderURL: URL) {
        let browserWindowController = AAPLBrowserWindowController(rootURL: folderURL)
        browserWindowController.showWindow(self)
        
        /*
         Add browserWindowController to browserWindowControllers, to keep it
         alive.
         */
        browserWindowControllers.insert(browserWindowController)
        
        /*
         Watch for the window to be closed, so we can let it and its
         controller go.
         */
        if let browserWindow = browserWindowController.window {
            NotificationCenter.default.addObserver(self, selector: #selector(AAPLAppDelegate.browserWindowWillClose(_:)), name: NSWindow.willCloseNotification, object: browserWindow)
        }
    }
    
    // CocoaSlideCollection's "File" -> "Browse Folder..." (Cmd+O) menu item sends this.
    /*
     Action method invoked by the "File" -> "Open Browser..." menu command.
     Prompts the user to choose a folder, using a standard Open panel, then opens
     a browser window for that folder using the method above.
     */
    @IBAction func openBrowserWindow(_: AnyObject) {
        
        let openPanel = NSOpenPanel()
        openPanel.prompt = "Choose"
        openPanel.message = "Choose a directory containing images:"
        openPanel.title = "Choose Directory"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        let pictureDirectories = NSSearchPathForDirectoriesInDomains(.picturesDirectory, .userDomainMask, true)
        openPanel.directoryURL = URL(fileURLWithPath: pictureDirectories[0])
        
        openPanel.begin {result in
            if result == NSApplication.ModalResponse.OK {
                self.openBrowserWindowForFolderURL(openPanel.urls[0])
            }
        }
    }
    
    // When a browser window is closed, release its BrowserWindowController.
    @objc func browserWindowWillClose(_ notification: Notification) {
        let browserWindow = notification.object as! NSWindow
        browserWindowControllers.remove(browserWindow.delegate as! AAPLBrowserWindowController)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: browserWindow)
    }
    
    
    //MARK: NSApplicationDelegate Methods
    
    // Browse a default folder on launch.
    func applicationDidFinishLaunching(_ notification: Notification) {
        self.openBrowserWindowForFolderURL(URL(fileURLWithPath: "/Library/Desktop Pictures"))
    }
    
}
