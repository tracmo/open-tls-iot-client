//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class AuthCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let didFinishHandler: (AuthCoordinator) -> Void
    
    init(navigationController: UINavigationController,
         didFinishHandler: @escaping (AuthCoordinator) -> Void) {
        self.navigationController = navigationController
        self.didFinishHandler = didFinishHandler
    }
    
    func start() {
        let authViewController =
            AuthViewController(authDidSucceedHandler: { [weak self] _ in
                guard let self = self else { return }
                self.navigationController.viewControllers = []
                self.didFinishHandler(self)
            })
        navigationController.viewControllers = [authViewController]
    }
}
