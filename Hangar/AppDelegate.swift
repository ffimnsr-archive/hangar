//
//  AppDelegate.swift
//  Hangar
//
//  Created by ffimnsr on 27/01/2018.
//  Copyright © 2018 vastorigins. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  
  var isVMsDisplayed = false
  let statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
  
  var images: [[String : String]]? = nil
  var containers: [[String : String]]? = nil
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    if let button = statusItem.button {
      button.image = NSImage(named: "StatusBarImage")
    }
    
    constructMenu()
    refresh()
  }
  
  func applicationWillTerminate(_ aNotification: Notification) {
  }
  
  func queryVboxManager(_ arguments: [String]) -> String {
    let pipe = Pipe()
    let process = Process()
    process.launchPath = "/usr/local/bin/vboxmanage"
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    process.launch()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
    return output
  }
  
  func removeVMsInMenu() {
    if images == nil {
      return
    }
    
    if isVMsDisplayed {
      if let menu = statusItem.menu {
        let count = images!.count + 1
        for _ in 0 ..< count {
          menu.removeItem(at: 1)
        }
      }
      isVMsDisplayed = false
    }
  }
  
  func createVMsInMenu() {
    if images == nil {
      return
    }
    
    if !isVMsDisplayed {
      if let menu = statusItem.menu {
        menu.insertItem(NSMenuItem.separator(), at: 1)
        for (index, element) in images!.enumerated() {
          var perl = false
          
          if containers != nil {
            perl = (containers?.contains(where: { $0 == element }))!
          }
          
          let running = perl ? "+" : "="
          let title = "[\(running)] \(element["name"]!)"
          let item = NSMenuItem(title: title, action: #selector(AppDelegate.launchVM(_:)), keyEquivalent: "")
          item.toolTip = element["uuid"]!
          menu.insertItem(item, at: 2 + index)
        }
        isVMsDisplayed = true
      }
    }
  }
  
  func storeImages() {
    let output = queryVboxManager(["list", "--sorted", "vms"])
    if !output.isEmpty {
      let tmp = output.components(separatedBy: "\n").map{$0.components(separatedBy: " ")}.filter{$0.count > 1}.map{value -> [String : String] in
        let name = value[0].replacingOccurrences(of: "\"", with: "")
        let uuid = value[1].replacingOccurrences(of: "[{}]", with: "", options: .regularExpression)
        return ["name": name, "uuid": uuid]
      }
      images = tmp
      return
    }
    images = nil
  }
  
  func storeContainers() {
    let output = queryVboxManager(["list", "--sorted", "runningvms"])
    if !output.isEmpty {
      let tmp = output.components(separatedBy: "\n").map{$0.components(separatedBy: " ")}.filter{$0.count > 1}.map{value -> [String : String] in
        let name = value[0].replacingOccurrences(of: "\"", with: "")
        let uuid = value[1].replacingOccurrences(of: "[{}]", with: "", options: .regularExpression)
        return ["name": name, "uuid": uuid]
      }
      containers = tmp
      return
    }
    containers = nil
  }
  
  func refresh() {
    storeImages()
    storeContainers()
    
    removeVMsInMenu()
    createVMsInMenu()
  }
  
  @objc func syncVMs(_ sender: NSMenuItem) {
    refresh()
  }
  
  @objc func launchVM(_ sender: NSMenuItem) {
    var perl = false
    let uuid = sender.toolTip!
    
    if containers != nil {
      perl = (containers?.contains(where: { $0["uuid"]! == uuid }))!
    }
    
    if perl {
      let output = queryVboxManager(["controlvm", uuid, "savestate"])
      print("suspending \(uuid)...")
      if (output.contains("100%")) {
        refresh()
      }
    } else {
      let output = queryVboxManager(["startvm", uuid, "--type", "headless"])
      print("launching \(uuid)...")
      if (output.contains("success")) {
        refresh()
      }
    }
  }
  
  func constructMenu() {
    let menu = NSMenu()
    menu.addItem(withTitle: "Synchronize", action: #selector(AppDelegate.syncVMs(_:)), keyEquivalent: "s")
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "Quit Hangar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    statusItem.menu = menu
  }
}

