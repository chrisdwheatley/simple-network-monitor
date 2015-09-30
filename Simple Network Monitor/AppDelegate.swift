//
//  AppDelegate.swift
//  Simple Network Monitor
//
//  Created by Chris Draycott-Wheatley on 16/09/2015.
//  Copyright © 2015 Chris Draycott-Wheatley. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var menu: NSMenu!
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    var currentActiveConnection: NSString = ""
    var currentTaskId: Int32 = 0
    
    // application launch
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        statusItem.menu = menu
        NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "checkActiveConnection:", userInfo: nil, repeats: true)
    }
    
    // check active connection, called every second from applicationDidFinishLaunching
    func checkActiveConnection(timer: NSTimer) {
        let activeConnection = NSTask()
        activeConnection.launchPath = "/bin/sh"
        activeConnection.arguments = ["-c", "/sbin/route get 10.10.10.10 | grep interface"]
        let acPipe = NSPipe()
        activeConnection.standardOutput = acPipe
        activeConnection.launch()
        activeConnection.waitUntilExit()
        let acData = acPipe.fileHandleForReading.readDataToEndOfFile()
        let acStr = NSString(data: acData, encoding: NSASCIIStringEncoding)
        let newActiveConnection = trimWhitespace(acStr as! String)
        if newActiveConnection != "" && newActiveConnection != currentActiveConnection {
            stopMonitor(currentTaskId)
            currentTaskId = startMonitor(strToArray(newActiveConnection)[1] as! String)
            currentActiveConnection = newActiveConnection
        }
    }
    
    // kills the monitor process when a new active connection is found
    func stopMonitor(pid: Int32) {
        let task = NSTask()
        task.launchPath = "/bin/kill"
        task.arguments = ["-9", String(pid)]
        task.launch()
    }
    
    // starts a new monitor process when a new active connection is found
    func startMonitor(connection: String) -> Int32 {
        let task = NSTask()
        task.launchPath = "/usr/sbin/netstat"
        task.arguments = ["-w1", "-I" + connection]
        let pipe = NSPipe()
        task.standardOutput = pipe
        let fh = pipe.fileHandleForReading
        fh.waitForDataInBackgroundAndNotify()
        task.launch()
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "receivedData:", name: NSFileHandleDataAvailableNotification, object: nil)
        
        return task.processIdentifier
    }
    
    // formats the data received from the monitor task to display in the status bar
    func receivedData(notif : NSNotification) {
        let fh:NSFileHandle = notif.object as! NSFileHandle
        let data = fh.availableData

        if data.length > 1 {
            fh.waitForDataInBackgroundAndNotify()
            let line = NSString(data: data, encoding: NSASCIIStringEncoding) as! String
            let values = trimWhitespace(line)
            let dlSpeedStr = strToArray(values)[2] as! String            
            let dlSpeed = Float(dlSpeedStr)
            
            if dlSpeed != nil {
                let kbps = dlSpeed! / 100
                let mbps = dlSpeed! / 100000
                if mbps < 1 {
                    statusItem.title = String(format: "%.2f", kbps) + "Kb/s▼"
                } else {
                    statusItem.title = String(format: "%.2f", mbps) + "Mb/s▼"
                }
            }
            
        } else {
            statusItem.title = "0.00 Kb/s▼"
        }
    }
    
    // website menu item
    @IBAction func websiteItemClicked(sender: NSMenuItem) {
        NSWorkspace.sharedWorkspace().openURL(NSURL(string: "https://swirlycheetah.github.io/simple-network-monitor/")!)
    }
    
    // donate menu item
    @IBAction func donateItemCLicked(sender: NSMenuItem) {
        NSWorkspace.sharedWorkspace().openURL(NSURL(string: "https://www.patreon.com/swirlycheetah")!)
    }
    
    // quit menu item
    @IBAction func quitItemClicked(sender: NSMenuItem) {
        NSApplication.sharedApplication().terminate(self)
    }
    
    func trimWhitespace(str: String) -> String {
        let pattern = "^\\s+|\\s+$|\\s+(?=\\s)"
        return str.stringByReplacingOccurrencesOfString(pattern, withString: "", options: .RegularExpressionSearch)
    }
    
    func strToArray(str: String) -> NSArray {
        return str.componentsSeparatedByString(" ")
    }

}

