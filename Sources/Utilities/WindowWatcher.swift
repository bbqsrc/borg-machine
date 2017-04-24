//
//  WindowWatcher.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 22/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class WindowWatcher {
    private static var observer: NSObjectProtocol? = nil
    private(set) static var windows = Set<NSWindow>()
    
    static func hold(_ window: NSWindow) {
        windows.insert(window)
        onWindowsChanged?(windows)
    }
    
    static func release(_ window: NSWindow) {
        windows.remove(window)
        onWindowsChanged?(windows)
    }
    
    static var onWindowsChanged: ((Set<NSWindow>) -> ())? = nil {
        didSet {
            if observer == nil {
                observer = NotificationCenter.default
                    .addObserver(forName: .NSWindowWillClose, object: nil, queue: .main, using: {
                        let closing = $0.object as! NSWindow
                        release(closing)
                    })
                onWindowsChanged?(windows)
            }
        }
    }
}
