//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class AppCoordinator: Coordinator {
    private var window: UIWindow
    
    private var children = [Coordinator]()
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        let homeCooridinator = HomeCoordinator(window: window)
        homeCooridinator.start()
        
        children.append(homeCooridinator)
    }
}
