//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

final class ButtonCell: UICollectionViewCell {
    enum State {
        case normal
        case disabled
        case busy
        case success
        case failure
        
        fileprivate var isLoadingIndicatorHidden: Bool {
            switch self {
            case .normal,
                 .disabled,
                 .success,
                 .failure: return true
            case .busy: return false
            }
        }
        
        fileprivate var borderWidth: CGFloat {
            switch self {
            case .normal,
                 .disabled,
                 .busy: return 0
            case .success,
                 .failure: return 8
            }
        }
        
        fileprivate var borderColor: CGColor {
            switch self {
            case .normal,
                 .disabled,
                 .busy: return UIColor.clear.cgColor
            case .success: return UIColor.success.cgColor
            case .failure: return UIColor.failure.cgColor
            }
        }
        
        fileprivate var isDisabledCoverHidden: Bool {
            switch self {
            case .normal,
                 .busy,
                 .success,
                 .failure: return true
            case .disabled: return false
            }
        }
    }
    
    var state: State = .normal {
        didSet {
            guard oldValue != state else { return }
            applyState()
        }
    }
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 48)
        label.textColor = .secondary
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.startAnimating()
        indicator.color = .secondary
        indicator.backgroundColor = .init(white: 0, alpha: 0.2)
        indicator.isHidden = state.isLoadingIndicatorHidden
        return indicator
    }()
    
    private lazy var disabledCover: UIView = {
        let view = UIView()
        view.backgroundColor = .init(white: 0, alpha: 0.2)
        return view
    }()
    
    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            alpha = isHighlighted ? 0.8 : 1
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayouts()
        applyState()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayouts()
        applyState()
    }
    
    private func setupLayouts() {
        backgroundColor = .accent
        clipsToBounds = true
        
        addSubviews(
            titleLabel
                .leading(to: leading, 16)
                .trailing(to: trailing, -16)
                .centerY(to: centerY),
            loadingIndicator
                .top(to: top)
                .leading(to: leading)
                .trailing(to: trailing)
                .bottom(to: bottom),
            disabledCover
                .top(to: top)
                .leading(to: leading)
                .trailing(to: trailing)
                .bottom(to: bottom)
            )
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }
    
    private func applyState() {
        loadingIndicator.isHidden = state.isLoadingIndicatorHidden
        layer.borderWidth = state.borderWidth
        layer.borderColor = state.borderColor
        disabledCover.isHidden = state.isDisabledCoverHidden
    }
    
    func display(title: String?) { titleLabel.text = title }
}

final class PencilBadge: UICollectionReusableView {
    private lazy var pencilImageView = UIImageView(image: UIImage(systemName: "pencil.circle",
                                                                  withConfiguration: UIImage.SymbolConfiguration(font: .systemFont(ofSize: 72)))?
                                                    .withTintColor(.accent, renderingMode: .alwaysOriginal))
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondary
        isUserInteractionEnabled = false
        setupLayouts()
    }
    
    private func setupLayouts() {
        addSubviews(pencilImageView
                        .top(to: top)
                        .leading(to: leading)
                        .trailing(to: trailing)
                        .bottom(to: bottom))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }
}

class FadeOnHighlightButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            alpha = isHighlighted ? 0.8 : 1
        }
    }
}

class RoundedButton: FadeOnHighlightButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

final class TextViewTitleView: UICollectionReusableView {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .accent
        label.font = .systemFont(ofSize: 24)
        return label
    }()
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupLayouts()
    }
    
    private func setupLayouts() {
        addSubviews(titleLabel
                        .top(to: top)
                        .leading(to: leading)
                        .trailing(to: trailing)
                        .bottom(to: bottom))
    }
    
    func display(title: String?) { titleLabel.text = title }
}

final class TextViewCell: UICollectionViewCell {
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .white
        textView.textColor = .black
        textView.autocorrectionType = .no
        textView.font = .systemFont(ofSize: 24)
        textView.layer.borderWidth = 2
        textView.layer.borderColor = UIColor.accent.cgColor
        return textView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayouts()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayouts()
    }
    
    private func setupLayouts() {
        backgroundColor = .clear
        
        addSubviews(textView
                        .top(to: top)
                        .leading(to: leading)
                        .trailing(to: trailing)
                        .bottom(to: bottom))
    }
}

final class OkCancelButtonsView: UICollectionReusableView {
    enum Action {
        case ok
        case cancel
    }
    
    let actionPublisher = PassthroughSubject<Action, Never>()
    
    private lazy var okButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.tintColor = .secondary
        button.titleLabel?.font = .systemFont(ofSize: 36)
        button.setTitle("OK", for: .normal)
        button.addAction(.init { [weak self] _ in
            guard let self = self else { return }
            self.actionPublisher.send(.ok)
        },
        for: .touchUpInside)
        return button
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.tintColor = .secondary
        button.titleLabel?.font = .systemFont(ofSize: 36)
        button.setTitle("CANCEL", for: .normal)
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
        container.spacing = 8
        
        addSubviews(container
                        .top(to: top, 16)
                        .leading(to: leading)
                        .trailing(to: trailing)
                        .bottom(to: bottom))
    }
}

final class LabelSwitchView: UICollectionReusableView {
    @Published
    private(set) var isOn: Bool = false
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .accent
        label.font = .systemFont(ofSize: 24)
        return label
    }()
    
    private lazy var mySwitch: UISwitch = {
        let mySwitch = UISwitch()
        mySwitch.publisher(for: \.isOn)
            .sink { [weak self] in
                guard let self = self else { return }
                self.isOn = $0
            }
            .store(in: &bag)
        mySwitch.addAction(.init { [weak self] _ in
            guard let self = self else { return }
            self.isOn = mySwitch.isOn
        },
        for: .valueChanged)
        return mySwitch
    }()
    
    private var bag = Set<AnyCancellable>()
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupLayouts()
    }
    
    private func setupLayouts() {
        addSubviews(
            titleLabel
                .top(to: top)
                .leading(to: leading)
                .bottom(to: bottom),
            mySwitch
                .leading(to: titleLabel.trailing, 16)
                .trailing(to: trailing, -4)
                .centerY(to: centerY)
        )
    }
    
    func display(title: String?) { titleLabel.text = title }
    func display(isSwitchOn: Bool) { mySwitch.isOn = isSwitchOn }
}
