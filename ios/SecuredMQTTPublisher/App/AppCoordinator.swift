//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class AppCoordinator: Cooridinator {
    private var window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        window.rootViewController = .home
        window.makeKeyAndVisible()
    }
}
