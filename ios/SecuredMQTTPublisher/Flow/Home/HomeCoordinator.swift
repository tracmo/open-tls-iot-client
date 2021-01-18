//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

final class HomeCoordinator: Cooridinator {
    private let window: UIWindow
    
    private var children = [Cooridinator]()
    
    private var bag = Set<AnyCancellable>()
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        let homeViewController = UIViewController.home
        homeViewController.coordinationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                switch $0 {
                case .about:
                    let aboutCoordinator = AboutCoordinator(presenter: homeViewController)
                    aboutCoordinator.didFinishPublisher
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] in
                            guard let self = self else { return }
                            self.children.removeAll { $0 === aboutCoordinator }
                        }
                        .store(in: &self.bag)
                    aboutCoordinator.start()
                    
                    self.children.append(aboutCoordinator)
                }
            }
            .store(in: &bag)
        window.rootViewController = homeViewController
        window.makeKeyAndVisible()
    }
}
