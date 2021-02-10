//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

final class OkCancelButtonsView: UICollectionReusableView {
    enum Action {
        case ok
        case cancel
    }
    
    let actionPublisher = PassthroughSubject<Action, Never>()
    
    private lazy var okButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.setTitleColor(.secondary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 21, weight: .semibold)
        button.setTitle("Ok", for: .normal)
        button.addAction(.init { [weak self] _ in
            guard let self = self else { return }
            self.actionPublisher.send(.ok)
        },
        for: .touchUpInside)
        return button
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .background
        button.setTitleColor(.accent, for: .normal)
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.accent.cgColor
        button.titleLabel?.font = .systemFont(ofSize: 21, weight: .semibold)
        button.setTitle("Cancel", for: .normal)
        button.addAction(.init { [weak self] _ in
            guard let self = self else { return }
            self.actionPublisher.send(.cancel)
        },
        for: .touchUpInside)
        return button
    }()
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupLayouts()
    }
    
    private func setupLayouts() {
        let container = UIStackView(arrangedSubviews: [cancelButton,
                                                       okButton])
        container.distribution = .fillEqually
        container.spacing = 15
        
        addSubviews(container
                        .top(to: top)
                        .leading(to: leading)
                        .trailing(to: trailing)
                        .bottom(to: bottom))
    }
}
