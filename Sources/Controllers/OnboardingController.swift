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

class OnboardingController: ViewController<OnboardingView>, NSTableViewDataSource, NSTableViewDelegate {
    var bag = DisposeBag()
    fileprivate let viewModel = OnboardingViewModel()
    
    static func inWindow() -> NSWindowController {
        let window = NSWindow(contentViewController: OnboardingController())
        let ctrl = NSWindowController(window: window)
        
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        
        return ctrl
    }
    
    override init() {
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func continueButtonTapped(_ sender: NSObject) {
        AppPreferences.main.repositoryPath = viewModel.repositoryPath.value
        AppPreferences.main.targetPaths = viewModel.targetPaths.value.map { $0.path }
        AppPreferences.main.passphrase = viewModel.passphrase.value
        
        AppPreferences.save()
        
        DispatchQueue.global(qos: .background).async {
            let task = BorgWrapper(preferences: AppPreferences)!.initialize()
            
            task.waitUntilExit()
        }
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
    
    override func viewWillAppear() {
        contentView.targetsTableView.dataSource = self
        contentView.targetsTableView.delegate = self
        
        if let passphrase = AppPreferences.main.passphrase {
            viewModel.passphrase.value = passphrase
        }
        
        if let targetPaths = AppPreferences.main.targetPaths {
            viewModel.targetPaths.value = targetPaths.map({ TargetPath(path: $0, size: nil) })
        }
        
        if let repositoryPath = AppPreferences.main.repositoryPath {
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
        
        viewModel.repositoryPath.asObservable()
            .bind(to: contentView.repositoryPathField.rx.text) => bag
        
        viewModel.targetPaths.asObservable()
            .subscribe(onNext: { [weak self] _ in
                self?.contentView.targetsTableView.reloadData()
            }) => bag
        
        viewModel.passphrase.asObservable()
            .subscribe(onNext: { [weak self] in
                self?.contentView.passphraseTextField.stringValue = $0
            }) => bag
        
        contentView.repositoryPathField.rx.text
            .filterNil().bind(to: viewModel.repositoryPath) => bag
        
        contentView.passphraseTextField.rx.text
            .filterNil().bind(to: viewModel.passphrase) => bag
    }
    
    override func viewWillDisappear() {
        bag = DisposeBag()
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
