//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/secured_mqtt_pub_ios
//  for the license and the contributors information.
//

import UIKit

final class HomeViewController: UIViewController {
    struct ButtonConfig: Hashable {
        let id = UUID()
        var isEditing: Bool
        var state: ButtonCell.State
        var action: Action
    }
    
    private enum Layout {
        static let utilityButtonSize: CGFloat = 48
    }
    
    private enum Section { case main }
    
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, ButtonConfig>.SingleCellType<ButtonCell>
    
    private enum ElementKind: String {
        case pencilBadge
    }
    
    private lazy var utilityButtonsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = isEditing
        return view
    }()
    
    private lazy var infoButton = UIButton(systemImageName: "info.circle.fill",
                                           size: Layout.utilityButtonSize) { _ in }
    
    private lazy var editButton = UIButton(systemImageName: "pencil.circle.fill",
                                           size: Layout.utilityButtonSize) { [weak self] _ in
        guard let self = self else { return }
        self.isEditing = true
    }
    
    private lazy var settingsButton = UIButton(systemImageName: "gearshape.fill",
                                               size: Layout.utilityButtonSize) { [weak self] _ in
        guard let self = self else { return }
        let settingsViewController = SettingsViewController(
            settings: Core.shared.dataStore.settings,
            settingsDidChangeHandler: { newSettings in
                Core.shared.dataStore.settings = newSettings
                self.displaySettings()
                self.errorMessageTextView.text = nil
                Core.shared.disconnect() {
                    if let error = $0.getError() {
                        self.errorMessageTextView.text = error.homeViewControllerErrorMessage
                    }
                }
                Core.shared.connect {
                    if let error = $0.getError() {
                        self.errorMessageTextView.text = error.homeViewControllerErrorMessage
                    }
                }
            })
        self.present(settingsViewController, in: .fullScreen)
    }
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 64)
        label.textAlignment = .center
        label.textColor = .accent
        label.text = Core.shared.dataStore.settings.homeTitle
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = false
        collectionView.delegate = self
        return collectionView
    }()
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        let pencilBadge = NSCollectionLayoutSupplementaryItem(layoutSize: .init(widthDimension: .absolute(72),
                                                                                heightDimension: .absolute(72)),
                                                              elementKind: ElementKind.pencilBadge.rawValue,
                                                              containerAnchor: .init(edges: [.top, .trailing],
                                                                                     absoluteOffset: .zero))
        
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(0.5),
                                                            heightDimension: .fractionalWidth(0.5)),
                                          supplementaryItems: [pencilBadge])
        item.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                                                         heightDimension: .fractionalWidth(0.5)),
                                                       subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }()
    
    private lazy var dataSource: DataSource = {
        let dataSource = DataSource(collectionView: collectionView,
                                    cellRegistrationHandler: { buttonCell, _, config in
                                        buttonCell.state = config.state
                                        buttonCell.display(title: config.action.title)
                                    })
        let pencilBadgeRegistration = UICollectionView.SupplementaryRegistration<PencilBadge>(elementKind: ElementKind.pencilBadge.rawValue) { [weak self] badge, _, _ in
            guard let self = self else { return }
            badge.isHidden = !self.isEditing
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: pencilBadgeRegistration, for: indexPath)
        }
        return dataSource
    }()
    
    lazy var errorMessageTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.font = .systemFont(ofSize: 24)
        textView.textAlignment = .center
        textView.textColor = .failure
        textView.backgroundColor = .clear
        return textView
    }()
    
    private lazy var okButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .accent
        button.tintColor = .secondary
        button.titleLabel?.font = .systemFont(ofSize: 36)
        button.setTitle("OK", for: .normal)
        button.addAction(
            .init { [weak self] _ in
                guard let self = self else { return }
                self.isEditing = false
            },
            for: .touchUpInside
        )
        button.isHidden = !isEditing
        return button
    }()
    
    override var isEditing: Bool {
        didSet {
            guard oldValue != isEditing else { return }
            utilityButtonsContainer.isHidden = isEditing
            okButton.isHidden = !isEditing
            buttonConfigs.mutateEach { $0.isEditing = isEditing }
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private var buttonConfigs: [ButtonConfig] {
        didSet {
            guard oldValue != buttonConfigs else { return }
            actions = buttonConfigs.map { $0.action }
            displayButtonConfigs()
        }
    }
    
    private var actions: [Action] {
        didSet {
            guard oldValue != actions else { return }
            actionsDidChangeHandler(actions)
        }
    }
    private let actionsDidChangeHandler: ([Action]) -> Void
    
    private var actionResultDisplayer: [Int: () -> ()] = [:]
    private let buttonBusyIntervalMinimum: TimeInterval = 2
    
    init(actions: [Action],
         actionsDidChangeHandler: @escaping ([Action]) -> Void) {
        self.actions = actions
        self.actionsDidChangeHandler = actionsDidChangeHandler
        self.buttonConfigs = actions.map { .init(isEditing: false, state: .normal, action: $0) }
        super.init(nibName: nil, bundle: nil)
        setupLayouts()
        displayButtonConfigs()
        displaySettings()
        
        Core.shared.connect {
            if let error = $0.getError() {
                self.errorMessageTextView.text = error.homeViewControllerErrorMessage
            }
        }
    }
    
    private func setupLayouts() {
        view.backgroundColor = .background
        
        let container = UIView()
        container.backgroundColor = .clear
        
        view.addSubviews(container
                            .top(to: view.safeAreaLayoutGuide.top, 16)
                            .leading(to: view.safeAreaLayoutGuide.leading, 16)
                            .trailing(to: view.safeAreaLayoutGuide.trailing, -16)
                            .bottom(to: view.safeAreaLayoutGuide.bottom, -16))
        
        container.addSubviews(
            utilityButtonsContainer
                .top(to: container.top)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .height(to: Layout.utilityButtonSize),
            titleLabel
                .top(to: utilityButtonsContainer.bottom, 16)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            collectionView
                .top(to: titleLabel.bottom, 16)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .height(to: collectionView.width, multiplier: 1),
            errorMessageTextView
                .top(to: collectionView.bottom, 16)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .height(to: 74),
            okButton
                .top(to: errorMessageTextView.bottom, 16)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .bottom(to: container.bottom)
                .height(to: 48)
        )
        
        utilityButtonsContainer.addSubviews(
            infoButton
                .top(to: utilityButtonsContainer.top)
                .leading(to: utilityButtonsContainer.leading)
                .width(to: Layout.utilityButtonSize)
                .height(to: Layout.utilityButtonSize),
            editButton
                .top(to: utilityButtonsContainer.top)
                .width(to: Layout.utilityButtonSize)
                .height(to: Layout.utilityButtonSize),
            settingsButton
                .top(to: utilityButtonsContainer.top)
                .leading(to: editButton.trailing, 16)
                .trailing(to: utilityButtonsContainer.trailing)
                .width(to: Layout.utilityButtonSize)
                .height(to: Layout.utilityButtonSize)
        )
    }
    
    private func displayButtonConfigs() {
        var collectionViewSnapshot = NSDiffableDataSourceSnapshot<Section, ButtonConfig>()
        collectionViewSnapshot.appendSections([.main])
        collectionViewSnapshot.appendItems(buttonConfigs)
        dataSource.apply(collectionViewSnapshot,
                         animatingDifferences: false)
    }
    
    private func displaySettings() { titleLabel.text = Core.shared.dataStore.settings.homeTitle }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        buttonConfigs.mutateEach { $0.state = .normal }
        errorMessageTextView.text = nil
    }
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isEditing else {
            presentActionEditViewController(buttonConfigIndex: indexPath.item)
            return
        }
        
        handleButtonSelected(buttonConfigIndex: indexPath.item)
    }
    
    private func presentActionEditViewController(buttonConfigIndex: Int) {
        guard let action = buttonConfigs[safe: buttonConfigIndex]?.action else { return }
        
        present(ActionEditViewController(
                    action: action,
                    actionDidChangeHandler: { [weak self] in
                        guard let self = self else { return }
                        self.buttonConfigs[safe: buttonConfigIndex]?.action = $0
                    }),
                in: .fullScreen)
    }
    
    private func handleButtonSelected(buttonConfigIndex: Int) {
        guard let buttonConfig = buttonConfigs[safe: buttonConfigIndex] else { return }
        
        guard buttonConfig.state != .busy else { return }
        
        buttonConfigs[safe: buttonConfigIndex]?.state = .busy
        errorMessageTextView.text = nil
        
        // Add a placeholder actionResultDisplayer
        actionResultDisplayer[buttonConfigIndex] = {}
        Timer.scheduledTimer(withTimeInterval: buttonBusyIntervalMinimum, repeats: false) { _ in
            guard let actionResultDisplayer = self.actionResultDisplayer[buttonConfigIndex] else { return }
            self.actionResultDisplayer[buttonConfigIndex] = nil
            actionResultDisplayer()
        }
        
        Core.shared.publish(message: buttonConfig.action.message,
                            to: buttonConfig.action.topic) {
            let error = $0.getError()
            
            let actionResultDisplayer = {
                self.errorMessageTextView.text = (error == nil) ? nil : error!.homeViewControllerErrorMessage
                self.buttonConfigs[safe: buttonConfigIndex]?.state = (error == nil) ? .success : .failure
                
                let soundEffect: SoundEffect = (error == nil) ? .success : .failure
                soundEffect.play()
            }
            
            let displayImmediately = self.isSettingsError(error)
            if displayImmediately {
                self.actionResultDisplayer[buttonConfigIndex] = nil
                actionResultDisplayer()
                return
            }
            
            let displayWhenButtonBusyIntervalMinimumReached = (self.actionResultDisplayer[buttonConfigIndex] != nil)
            if displayWhenButtonBusyIntervalMinimumReached {
                self.actionResultDisplayer[buttonConfigIndex] = actionResultDisplayer
                return
            }
            
            actionResultDisplayer()
        }
    }
    
    private func isSettingsError(_ error: Error?) -> Bool {
        guard let error = error else { return false }
        
        if let connectError = error as? MQTTSessionManagerClient.ConnectError {
            switch connectError {
            case .endpointEmpty,
                 .certificateEmpty,
                 .privateKeyEmpty,
                 .clientCertificatesCreateFailure: return true
            }
        }
        
        if let publishError = error as? MQTTSessionManagerClient.PublishError {
            switch publishError {
            case .messageEmpty,
                 .topicEmpty,
                 .clientNotConnected: return true
            case .timeout: return false
            }
        }
        
        if let convertError = error as? CertificateConverter.ConvertError {
            switch convertError {
            case .certificateFormatIncorrect,
                 .privateKeyFormatIncorrect,
                 .certificateAndPrivateKeyMismatch,
                 .p12CreateFailure,
                 .unknown: return true
            }
        }
        
        return false
    }
}

extension Error {
    fileprivate var homeViewControllerErrorMessage: String {
        if let connectError = self as? MQTTSessionManagerClient.ConnectError {
            switch connectError {
            case .endpointEmpty: return "MQTT endpoint empty"
            case .certificateEmpty: return "certificate empty"
            case .privateKeyEmpty: return "private key empty"
            case .clientCertificatesCreateFailure: return "certificate or private key incorrect"
            }
        }
        
        if let publishError = self as? MQTTSessionManagerClient.PublishError {
            switch publishError {
            case .messageEmpty: return "message Empty"
            case .topicEmpty: return "MQTT topic Empty"
            case .clientNotConnected(let connectError):
                return (connectError == nil) ?
                    "client not connected" :
                    connectError!.homeViewControllerErrorMessage
            case .timeout: return "timeout"
            }
        }
        
        if let convertError = self as? CertificateConverter.ConvertError {
            switch convertError {
            case .certificateFormatIncorrect: return "certificate format incorrect"
            case .privateKeyFormatIncorrect: return "private key format incorrect"
            case .certificateAndPrivateKeyMismatch: return "certificate and private key mismatch"
            case .p12CreateFailure: return "certificate or private key incorrect"
            case .unknown: return "certificate or private key or root CA incorrect"
            }
        }
        
        if (self as NSError).domain == "\(kCFErrorDomainCFNetwork)",
           (self as NSError).code == Int(CFNetworkErrors.cfHostErrorUnknown.rawValue) {
            let getAddrInfoErrorCodeNumber = (self as NSError).userInfo["\(kCFGetAddrInfoFailureKey)"] as! CFNumber
            
            var getAddrInfoErrorCode: Int32 = -1
            CFNumberGetValue(getAddrInfoErrorCodeNumber, .sInt32Type, &getAddrInfoErrorCode)
            switch getAddrInfoErrorCode {
            case EAI_ADDRFAMILY: return "address family for hostname not supported"
            case EAI_AGAIN: return "temporary failure in name resolution"
            case EAI_BADFLAGS: return "invalid value for ai_flags"
            case EAI_FAIL: return "non-recoverable failure in name resolution"
            case EAI_FAMILY: return "ai_family not supported"
            case EAI_MEMORY: return "memory allocation failure"
            case EAI_NODATA: return "no address associated with hostname"
            case EAI_NONAME: return "hostname nor servname provided, or not known"
            case EAI_SERVICE: return "servname not supported for ai_socktype"
            case EAI_SOCKTYPE: return "ai_socktype not supported"
            case EAI_SYSTEM: return "system error returned in errno"
            case EAI_BADHINTS: return "invalid value for hints"
            case EAI_PROTOCOL: return "resolved protocol is unknown"
            case EAI_OVERFLOW: return "argument buffer overflow"
            default: break
            }
        }
        
        return localizedDescription
    }
}
