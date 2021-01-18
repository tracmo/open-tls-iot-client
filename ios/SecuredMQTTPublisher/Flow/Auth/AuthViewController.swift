//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

final class AuthViewController: UIViewController {
    private lazy var titleLabel: UILabel = {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Secured MQTT Publisher"
        let label = UILabel()
        label.font = .systemFont(ofSize: 64)
        label.textAlignment = .center
        label.textColor = .accent
        label.text = appName
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private lazy var authButton: UIButton = {
        let systemImageName: String
        switch DeviceOwnerAuthenticator.getBiometryType() {
        case .none: systemImageName = "questionmark.square.dashed"
        case .touchID: systemImageName  = "touchid"
        case .faceID: systemImageName = "faceid"
        @unknown default: systemImageName = "questionmark.square.dashed"
        }
        
        let systemImage =
            UIImage(systemName: systemImageName,
                    withConfiguration: UIImage.SymbolConfiguration(font: .systemFont(ofSize: 64)))?
            .withTintColor(.secondary, renderingMode: .alwaysOriginal)
        
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.setImage(systemImage, for: .normal)
        button.addAction(.init { [weak self] _ in
            guard let self = self else { return }
            self.auth()
        },
        for: .touchUpInside)
        return button
    }()
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    
    private var bag = Set<AnyCancellable>()
    
    init() {
        super.init(nibName: nil, bundle: nil)
        setupLayouts()
    }
    
    private func setupLayouts() {
        view.backgroundColor = .background
        
        let container = UIView()
        container.backgroundColor = .clear
        
        view.addSubviews(container
                            .leading(to: view.safeAreaLayoutGuide.leading, 16)
                            .trailing(to: view.safeAreaLayoutGuide.trailing, -16)
                            .centerY(to: view.safeAreaLayoutGuide.centerY))
        
        container.addSubviews(
            titleLabel
                .top(to: container.top)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            authButton
                .top(to: titleLabel.bottom, 40)
                .centerX(to: container.centerX)
                .bottom(to: container.bottom)
                .width(to: 100)
                .height(to: 100)
        )
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func auth() {
        DeviceOwnerAuthenticator.auth()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: {
                guard $0.getError() == nil else { return }
                UIWindow.auth?.isHidden = true
            }, receiveValue: { _ in })
            .store(in: &self.bag)
    }
}
