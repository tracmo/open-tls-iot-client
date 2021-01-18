//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class SettingsCoordinator: Cooridinator {
    private let presenter: UIViewController
    private let didFinishHandler: (SettingsCoordinator) -> Void
    
    init(presenter: UIViewController,
         didFinishHandler: @escaping (SettingsCoordinator) -> Void) {
        self.presenter = presenter
        self.didFinishHandler = didFinishHandler
    }
    
    func start() {
        let settingsViewController =
            SettingsViewController(settings: Core.shared.dataStore.settings,
                                   settingsDidChangeHandler: { Core.shared.dataStore.settings = $0 },
                                   didDisappearHandler: { [weak self] _ in
                                    guard let self = self else { return }
                                    self.didFinishHandler(self)
                                   })
        
        presenter.present(settingsViewController, in: .fullScreen, animated: true)
    }
}
