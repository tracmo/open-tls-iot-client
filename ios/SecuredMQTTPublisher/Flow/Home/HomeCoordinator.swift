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
                                }
                               })
        window.rootViewController = homeViewController
        window.makeKeyAndVisible()
    }
    
    private func coordinateWithAbout(presenter: UIViewController) {
        let aboutCoordinator = AboutCoordinator(presenter: presenter, didFinishHandler: { [weak self] coordinator in
            guard let self = self else { return }
            self.children.removeAll { $0 === coordinator }
        })
        aboutCoordinator.start()
        
        children.append(aboutCoordinator)
    }
}
