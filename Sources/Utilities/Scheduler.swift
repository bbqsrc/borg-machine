//
//  Scheduler.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 25/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Foundation

class ScheduledJob {
    private let scheduler: Scheduler
    fileprivate weak var timer: Timer!
    fileprivate(set) var isCancelled = false
    
    fileprivate init(scheduler: Scheduler) {
        self.scheduler = scheduler
    }
    
    func cancel() -> Bool {
        if isCancelled {
            return true
        }
        
        return scheduler.cancel(job: self)
    }
}

class Scheduler {
    private var timers = [Timer]()
    private var jobs = [ScheduledJob]()
    
    private func add(timer: Timer) {
        timers.append(timer)
        RunLoop.current.add(timer, forMode: .defaultRunLoopMode)
    }
    
    @discardableResult
    private func remove(timer: Timer) -> Bool {
        if let i = timers.index(of: timer) {
            timers.remove(at: i)
            timer.invalidate()
            return true
        }
        
        return false
    }
    
    private func iterate(with job: ScheduledJob, when: Date, block: @escaping (Date) -> Date?) {
        let timer = Timer(fireAt: when, interval: 0, repeats: false, block: { t in
            if let nextDate = block(when) {
                _ = self.iterate(with: job, when: nextDate, block: block)
            }
            
            self.remove(timer: t)
        })
        
        job.timer = timer
        add(timer: timer)
    }
    
    @discardableResult
    func at(_ date: Date, block: @escaping (Date) -> Date?) -> ScheduledJob {
        print("Scheduled at \(date.iso8601String())")
        let job = ScheduledJob(scheduler: self)
        iterate(with: job, when: date, block: block)
        
        jobs.append(job)
        
        return job
    }
    
    @discardableResult
    func cancel(job: ScheduledJob) -> Bool {
        if let timer = job.timer {
            remove(timer: timer)
            
            if let i = jobs.index(where: { $0 === job }) {
                jobs.remove(at: i)
            }
            
            job.isCancelled = true
            
            return true
        }
        
        return false
    }
    
    func reset() {
        timers.forEach { $0.invalidate() }
        jobs.forEach { $0.isCancelled = true }
        
        timers = []
        jobs = []
    }
}
