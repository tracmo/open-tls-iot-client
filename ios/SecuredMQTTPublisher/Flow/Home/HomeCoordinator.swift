//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class HomeCoordinator: Coordinator {
    private let navigationController: UINavigationController
    
    private var children = [Coordinator]()
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let homeViewController =
            HomeViewController(core: .shared,
                               coordinationHandler: { [weak self] in
                                guard let self = self else { return }
                                switch $1 {
                                case .about: self.showAbout(presenter: $0)
                                case .actionEdit(let index): self.showActionEdit(presenter: $0, actionIndex: index)
                                case .settings: self.showSettings(presenter: $0)
                                }
                               })
        navigationController.viewControllers = [homeViewController]
    }
    
    private func showAbout(presenter: UIViewController) {
        let aboutCoordinator =
            AboutCoordinator(presenter: presenter,
                             didFinishHandler: { [weak self] coordinator in
                                guard let self = self else { return }
                                self.children.removeAll { $0 === coordinator }
                             })
        aboutCoordinator.start()
        
        children.append(aboutCoordinator)
    }
    
    private func showActionEdit(presenter: UIViewController, actionIndex: Int) {
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
    
    private func showSettings(presenter: UIViewController) {
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
