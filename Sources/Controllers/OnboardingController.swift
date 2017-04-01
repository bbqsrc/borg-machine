//
//  OnboardingController.swift
//  BorgMachine
//
//  Created by Brendan Molloy on 1/4/17.
//  Copyright © 2017 Brendan Molloy. All rights reserved.
//

import Cocoa

class OnboardingViewModel {
    private unowned let view: OnboardingView
    
    var repositoryPath: String = "" {
        didSet {
            if oldValue != repositoryPath {
                view.repositoryPathField.stringValue = repositoryPath
            }
        }
    }
    
    init(view: OnboardingView) {
        self.view = view
    }
}

class OnboardingController: ViewController<OnboardingView> {
    private var viewModel: OnboardingViewModel!
    
    override init() {
        super.init()
    }
    
    override func loadView() {
        super.loadView()
        
        viewModel = OnboardingViewModel(view: contentView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func continueButtonTapped(_ sender: NSObject) {
        AppPreferences.main.repositoryPath = viewModel.repositoryPath
        
        AppPreferences.save()
    }

    func repositoryPathChooseButtonTapped(_ sender: NSObject) {
        let dialog = NSOpenPanel()
        
        dialog.title = "Select Repository Directory"
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.allowsMultipleSelection = false
        dialog.canCreateDirectories = true
        
        if dialog.runModal() == NSModalResponseOK, let url = dialog.url {
            viewModel.repositoryPath = url.path
        }
    }
    
    override func viewWillAppear() {
        contentView.repositoryPathButton.action = #selector(OnboardingController.repositoryPathChooseButtonTapped(_:))
        contentView.continueButton.action = #selector(OnboardingController.continueButtonTapped(_:))
    }
}
