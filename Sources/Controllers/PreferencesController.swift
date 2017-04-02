//
//  PreferencesController.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class PreferencesController: ViewController<PreferencesView> {
    static func window() -> NSWindowController {
        let window = NSWindow(contentViewController: PreferencesController())
        let ctrl = NSWindowController(window: window)
        window.title = "Borg Machine Preferences"
        
        return ctrl
    }
    
    override func viewDidLoad() {
        
    }
}
