//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class HomeCoordinator: Cooridinator {
    private let window: UIWindow
    
    private var children = [Cooridinator]()
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        let homeViewController =
            HomeViewController(core: .shared,
                               coordinationHandler: { [weak self] in
                                guard let self = self else { return }
                                switch $1 {
                                case .about: self.coordinateWithAbout(presenter: $0)
                                case .actionEdit(let index): self.coordinateWithActionEdit(presenter: $0, actionIndex: index)
                                case .settings: self.coordinateWithSettings(presenter: $0)
                                }
                               })
        window.rootViewController = homeViewController
        window.makeKeyAndVisible()
    }
    
    private func coordinateWithAbout(presenter: UIViewController) {
        let aboutCoordinator =
            AboutCoordinator(presenter: presenter,
                             didFinishHandler: { [weak self] coordinator in
                                guard let self = self else { return }
                                self.children.removeAll { $0 === coordinator }
                             })
        aboutCoordinator.start()
        
        children.append(aboutCoordinator)
    }
    
    private func coordinateWithActionEdit(presenter: UIViewController, actionIndex: Int) {
        let actionEditCoordinator =
            ActionEditCoordinator(presenter: presenter,
                                  actionIndex: actionIndex,
                                  didFinishHandler: { [weak self] coordinator in
            guard let self = self else { return }
            self.children.removeAll { $0 === coordinator }
        })
        actionEditCoordinator.start()
        
        children.append(actionEditCoordinator)
    }
    
    private func coordinateWithSettings(presenter: UIViewController) {
        let settingsCoordinator =
            SettingsCoordinator(presenter: presenter,
                                didFinishHandler: { [weak self] coordinator in
                                    guard let self = self else { return }
                                    self.children.removeAll { $0 === coordinator }
                                })
        settingsCoordinator.start()
        
        children.append(settingsCoordinator)
    }
}
