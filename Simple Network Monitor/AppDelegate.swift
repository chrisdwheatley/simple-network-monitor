//
//  AppDelegate.swift
//  Simple Network Monitor
//
//  Created by Chris Wheatley on 16/09/2015.
//  Copyright © 2015 Chris Wheatley. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var menu: NSMenu!
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    var currentActiveConnection: NSString = ""
    var currentTaskId: Int32 = 0
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        statusItem.menu = menu
        NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "checkActiveConnection:", userInfo: nil, repeats: true)
    }
    
    @IBAction func quitItemClicked(sender: NSMenuItem) {
        NSApplication.sharedApplication().terminate(self)
    }
    
    func checkActiveConnection(timer: NSTimer) {
        let activeConnection = NSTask()
        activeConnection.launchPath = "/bin/sh"
        activeConnection.arguments = ["-c", "/sbin/route get 10.10.10.10 | grep interface"]
        let acPipe = NSPipe()
        activeConnection.standardOutput = acPipe
        activeConnection.launch()
        activeConnection.waitUntilExit()
        let acData = acPipe.fileHandleForReading.readDataToEndOfFile()
        let acStr = NSString(data: acData, encoding: NSASCIIStringEncoding) as! String
        let newActiveConnection = trimWhitespace(acStr as String)
        if newActiveConnection != "" && newActiveConnection != currentActiveConnection {
            stopMonitor(currentTaskId)
            currentTaskId = startMonitor(strToArray(newActiveConnection)[1] as! String)
            currentActiveConnection = newActiveConnection
        }
    }
    
    func stopMonitor(pid: Int32) {
        let task = NSTask()
        task.launchPath = "/bin/kill"
        let x = String(pid)
        task.arguments = ["-9", x]
        task.launch()
    }
    
    func startMonitor(connection: String) -> Int32 {
        let task = NSTask()
        task.launchPath = "/usr/sbin/netstat"
        task.arguments = ["-w1", "-I" + (connection)]
        let pipe = NSPipe()
        task.standardOutput = pipe
        let fh = pipe.fileHandleForReading
        fh.waitForDataInBackgroundAndNotify()
        task.launch()
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "receivedData:", name: NSFileHandleDataAvailableNotification, object: nil)
        
        return task.processIdentifier
    }
    
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
    
    func trimWhitespace(str: String) -> String {
        let pattern = "^\\s+|\\s+$|\\s+(?=\\s)"
        return str.stringByReplacingOccurrencesOfString(pattern, withString: "", options: .RegularExpressionSearch)
    }
    
    func strToArray(str: String) -> NSArray {
        return str.componentsSeparatedByString(" ")
    }

}

