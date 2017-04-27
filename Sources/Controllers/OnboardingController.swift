//
//  OnboardingController.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import RxOptional

fileprivate class OnboardingViewModel {
    let bag = DisposeBag()
    
    let repositoryPath = Variable<String>("")
    let passphrase = Variable<String>("")
    let targetPaths = Variable<[TargetPath]>([])
    let scheduleRules = Variable<[ScheduleRule]>([])
    
    func updateTargetPath(_ path: String, size: Int64) {
        if let i = targetPaths.value.index(where: { $0.path == path }) {
            var values = targetPaths.value
            
            values[i] = TargetPath(path: path, size: size)
            targetPaths.value = values
        }
    }
    
    private func processSize(of targetPath: TargetPath) {
        let path = targetPath.path
        
        sizeProcessingQueue.async { [weak self] in
            guard let `self` = self else { return }
            
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            
            let url = URL(fileURLWithPath: path)
            let size: Int64
            
            if isDirectory.boolValue {
                size = (try? FileManager.default.allocatedDirectorySize(at: url)) ?? 0
            } else if let res = try? url.resourceValues(forKeys: [.totalFileSizeKey, .fileSizeKey]) {
                size = Int64(res.totalFileSize ?? res.fileSize ?? 0)
            } else {
                size = 0
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.updateTargetPath(path, size: size)
            }
        }
    }
    
    init() {
        targetPaths.asObservable()
            .map({
                return $0.filter({ $0.size == nil })
            })
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                $0.forEach(self.processSize(of:))
            }) => bag
    }
}

class TargetTableDelegate: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private unowned let viewModel: OnboardingViewModel
    
    fileprivate init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.targetPaths.value.count
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        
        let cell = tableView.make(withIdentifier: column.identifier, owner: self) as! NSTableCellView
        let target = viewModel.targetPaths.value[row]
        
        switch column.identifier {
        case "icon":
            let icon = NSWorkspace.shared().icon(forFile: target.path)
            cell.imageView?.image = icon
        case "path":
            cell.textField?.stringValue = target.path
        case "size":
            if let size = target.size {
                cell.textField?.stringValue = ByteCountFormatter.string(
                    fromByteCount: size,
                    countStyle: ByteCountFormatter.CountStyle.file
                )
            } else {
                cell.textField?.stringValue = "…"
            }
        default:
            break
        }
        
        return cell
    }
}

class ScheduleTableDelegate: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private unowned let viewModel: OnboardingViewModel
    
    fileprivate init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.scheduleRules.value.count
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        
        let cell = tableView.make(withIdentifier: column.identifier, owner: self) as! NSTableCellView
        let sch = viewModel.scheduleRules.value[row]
        
        switch column.identifier {
        case "time":
            cell.textField?.stringValue = String(format: "%d:%02d", arguments: [sch.hour, sch.minute])
        case "rule":
            cell.textField?.stringValue = sch.rule.description
        default:
            break
        }
        
        return cell
    }
}

class OnboardingController: ViewController<OnboardingView>, NSPopoverDelegate {
    var bag = DisposeBag()
    fileprivate let viewModel = OnboardingViewModel()
    
    static func inWindow() -> NSWindowController {
        let window = NSWindow(contentViewController: OnboardingController())
        let ctrl = NSWindowController(window: window)
        
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.closable, .titled]
        if #available(OSX 10.12, *) {
            window.tabbingMode = .disallowed
        }
        
        return ctrl
    }
    
    let targetDelegate: TargetTableDelegate
    let scheduleDelegate: ScheduleTableDelegate
    
    override init() {
        targetDelegate = TargetTableDelegate(viewModel: viewModel)
        scheduleDelegate = ScheduleTableDelegate(viewModel: viewModel)
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func continueButtonTapped(_ sender: NSObject) {
        AppPreferences.main.value.repositoryPath = viewModel.repositoryPath.value
        AppPreferences.main.value.targetPaths = viewModel.targetPaths.value.map { $0.path }
        AppPreferences.main.value.passphrase = viewModel.passphrase.value
        AppPreferences.main.value.schedule = viewModel.scheduleRules.value
        
        AppPreferences.save()
        
        let task = BorgWrapper(preferences: AppPreferences)!.initialize()
        
        task.onComplete = {
            DispatchQueue.main.async {
                let alert = NSAlert()
                
                alert.addButton(withTitle: "OK")
                
                alert.alertStyle = .informational
                alert.messageText = "Repository Created"
                alert.informativeText = "Your repository at \(self.viewModel.repositoryPath.value) has been created. You may now make backups."
                
                alert.runModal()
            }
        }
        
        task.launch()
    }

    func repositoryPathChooseButtonTapped(_ sender: NSObject) {
        let dialog = NSOpenPanel()
        
        dialog.title = "Select Repository Directory"
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.allowsMultipleSelection = false
        dialog.canCreateDirectories = true
        
        if dialog.runModal() == NSModalResponseOK, let url = dialog.url {
            viewModel.repositoryPath.value = url.path
        }
    }
    
    func targetAddButtonTapped(_ sender: NSObject) {
        let dialog = NSOpenPanel()
        
        dialog.title = "Select Target For Backup"
        dialog.canChooseFiles = true
        dialog.canChooseDirectories = true
        dialog.allowsMultipleSelection = true
        dialog.canCreateDirectories = false
        
        if dialog.runModal() == NSModalResponseOK {
            let paths = dialog.urls.map({ $0.path })
                .filter({ path in
                    !viewModel.targetPaths.value.contains(where: { $0.path == path })
                })
                .map({ TargetPath(path: $0, size: nil) })
            
            viewModel.targetPaths.value = (viewModel.targetPaths.value + paths).sorted(by: { $0.path < $1.path })
        }
    }
    
    func targetRemoveButtonTapped(_ sender: NSObject) {
        let indexes = contentView.targetsTableView.selectedRowIndexes
        var paths = viewModel.targetPaths.value
        
        indexes.reversed().forEach {
            paths.remove(at: $0)
        }
        
        viewModel.targetPaths.value = paths
    }
    
    var schedulePopup: NSPopover? = nil
    
    class ScheduleModalController: ViewController<ScheduleModalView> {}
    
    func scheduleAddButtonTapped(_ sender: NSView) {
        if schedulePopup != nil { return }
        
        let popover = NSPopover()
        
        let vc = ScheduleModalController()
        popover.contentViewController = vc
        popover.appearance = NSAppearance(named: NSAppearanceNameVibrantLight)
        popover.animates = true
        popover.behavior = .semitransient
        popover.delegate = self
        
        schedulePopup = popover
        
        popover.show(relativeTo: contentView.scheduleAddButton.bounds, of: sender, preferredEdge: .maxY)
        
        vc.contentView.continueButton.rx.tap
            .subscribe(onNext: {
                let c = Calendar.current
                    .dateComponents(Set([.hour, .minute]), from: vc.contentView.timeView.dateValue)
                let d = vc.contentView.weekdaySegment.selectedSegments
                    .flatMap({ Weekday(rawValue: $0 + 1) })
                let r = RecurrenceRule(frequency: .daily, byDay: d)
                
                let rule = ScheduleRule(hour: UInt(c.hour!), minute: UInt(c.minute!), rule: r)!
                self.viewModel.scheduleRules.value.append(rule)
                
                popover.performClose(vc.contentView.continueButton)
            }) => bag
        
    }
    
    func popoverDidClose(_ notification: Notification) {
        schedulePopup = nil
    }
    
    override func viewWillAppear() {
        contentView.targetsTableView.dataSource = targetDelegate
        contentView.targetsTableView.delegate = targetDelegate
        
        contentView.scheduleTableView.dataSource = scheduleDelegate
        contentView.scheduleTableView.delegate = scheduleDelegate
        
        if let passphrase = AppPreferences.main.value.passphrase {
            viewModel.passphrase.value = passphrase
        }
        
        let targetPaths = AppPreferences.main.value.targetPaths
        viewModel.targetPaths.value = targetPaths.map({ TargetPath(path: $0, size: nil) })
        
        let schedule = AppPreferences.main.value.schedule
        viewModel.scheduleRules.value = schedule
        
        if let repositoryPath = AppPreferences.main.value.repositoryPath {
            viewModel.repositoryPath.value = repositoryPath
        }
        
        contentView.repositoryPathButton.action =
            #selector(OnboardingController.repositoryPathChooseButtonTapped(_:))
        contentView.continueButton.action =
            #selector(OnboardingController.continueButtonTapped(_:))
        contentView.targetAddButton.action =
            #selector(OnboardingController.targetAddButtonTapped(_:))
        contentView.targetRemoveButton.action =
            #selector(OnboardingController.targetRemoveButtonTapped(_:))
        contentView.scheduleAddButton.action =
            #selector(OnboardingController.scheduleAddButtonTapped(_:))
        
        viewModel.repositoryPath.asObservable()
            .bindTo(contentView.repositoryPathField.rx.text) => bag
        
        viewModel.targetPaths.asObservable()
            .subscribe(onNext: { [weak self] _ in
                self?.contentView.targetsTableView.reloadData()
            }) => bag
        
        viewModel.scheduleRules.asObservable()
            .subscribe(onNext: { [weak self] _ in
                self?.contentView.scheduleTableView.reloadData()
            }) => bag
        
        viewModel.passphrase.asObservable()
            .subscribe(onNext: { [weak self] in
                self?.contentView.passphraseTextField.stringValue = $0
            }) => bag
        
        contentView.repositoryPathField.rx.text
            .filterNil().bindTo(viewModel.repositoryPath) => bag
        
        contentView.passphraseTextField.rx.text
            .filterNil().bindTo(viewModel.passphrase) => bag
    }
    
    override func viewWillDisappear() {
        bag = DisposeBag()
    }
}

fileprivate let sizeProcessingQueue = DispatchQueue(
    label: "BorgMachine.SizeProcessingQueue",
    qos: .background,
    attributes: [],
    autoreleaseFrequency: .inherit,
    target: nil
)

fileprivate struct TargetPath {
    let path: String
    let size: Int64?
}
