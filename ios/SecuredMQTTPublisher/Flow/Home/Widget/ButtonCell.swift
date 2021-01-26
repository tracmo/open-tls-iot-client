//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

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
                 .busy,
                 .success,
                 .failure: return 16
            }
        }
        
        fileprivate var borderColor: CGColor {
            switch self {
            case .normal,
                 .disabled,
                 .busy: return UIColor.accent.cgColor
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
        label.textColor = .accent
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
        backgroundColor = .secondary
        clipsToBounds = true
        
        addSubviews(
            titleLabel
                .leading(to: leading, 20)
                .trailing(to: trailing, -20)
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
