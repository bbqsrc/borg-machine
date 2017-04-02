//
//  OnboardingView.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class OnboardingView: NSView, Nibbable {
    @IBOutlet weak var repositoryPathField: NSTextField!
    @IBOutlet weak var repositoryPathButton: NSButton!
    @IBOutlet weak var continueButton: NSButton!
    @IBOutlet weak var targetsTableView: NSTableView!
    @IBOutlet weak var targetAddButton: NSButton!
    @IBOutlet weak var targetRemoveButton: NSButton!
    @IBOutlet weak var passphraseTextField: NSSecureTextField!
}
