//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

/// Displays a QR code for sharing an NFC secret with another device.
final class QRCodeDisplayViewController: UIViewController {

    private let qrCodeImage: UIImage
    private let secretLabel: String
    private let actionTitle: String

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Share NFC Secret"
        label.textColor = .accent
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Scan this QR code on your other device to share the NFC secret for \"\(actionTitle)\""
        label.textColor = .label
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var qrImageView: UIImageView = {
        let imageView = UIImageView(image: qrCodeImage)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        imageView.layer.cornerRadius = 12
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.systemGray4.cgColor
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var tagLabel: UILabel = {
        let label = UILabel()
        label.text = "Tag: \(secretLabel)"
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }()

    private lazy var warningLabel: UILabel = {
        let label = UILabel()
        label.text = "⚠️ Only share with your own trusted devices"
        label.textColor = .systemOrange
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var doneButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.setTitleColor(.secondary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitle("Done", for: .normal)
        button.addAction(
            .init { [weak self] _ in
                self?.dismiss(animated: true)
            },
            for: .touchUpInside
        )
        return button
    }()

    init(qrCodeImage: UIImage, secretLabel: String, actionTitle: String) {
        self.qrCodeImage = qrCodeImage
        self.secretLabel = secretLabel
        self.actionTitle = actionTitle
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .background

        let container = UIView()
        container.backgroundColor = .clear

        view.addSubviews(
            container
                .top(to: view.safeAreaLayoutGuide.top, 32)
                .leading(to: view.safeAreaLayoutGuide.leading, 20)
                .trailing(to: view.safeAreaLayoutGuide.trailing, -20)
                .bottom(to: view.safeAreaLayoutGuide.bottom, -20)
        )

        container.addSubviews(
            titleLabel
                .top(to: container.top)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            instructionLabel
                .top(to: titleLabel.bottom, 16)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            qrImageView
                .top(to: instructionLabel.bottom, 24)
                .centerX(to: container.centerX)
                .width(to: 280)
                .height(to: 280),
            tagLabel
                .top(to: qrImageView.bottom, 16)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            warningLabel
                .top(to: tagLabel.bottom, 12)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            doneButton
                .bottom(to: container.bottom)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .height(to: 46)
        )
    }
}
