//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

final class AboutCoordinator: Cooridinator {
    let didFinishPublisher = PassthroughSubject<Void, Never>()
    
    private let presenter: UIViewController
    
    private var bag = Set<AnyCancellable>()
    
    init(presenter: UIViewController) {
        self.presenter = presenter
    }
    
    func start() {
        let aboutViewController = UIViewController.about
        aboutViewController.didDisappearPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.didFinishPublisher.send()
            }
            .store(in: &bag)
        presenter.present(aboutViewController, in: .pageSheet, animated: true)
    }
}
