//
//  ScheduleModalView.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 28/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class ScheduleModalView: NSView, Nibbable {
    @IBOutlet weak var weekdaySegment: NSSegmentedControl!
    @IBOutlet weak var timeView: NSDatePicker!
    @IBOutlet weak var continueButton: NSButton!
}
