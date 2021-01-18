//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

fileprivate extension Action {
    var isEmpty: Bool {
        title.isEmpty && topic.isEmpty && message.isEmpty
    }
}

final class HomeViewController: UIViewController {
    struct ButtonConfig: Hashable {
        let id = UUID()
        var title: String
        var isEditing: Bool
        var isHidden: Bool
        var state: ButtonCell.State
    }
    enum Coordination {
        case about
        case actionEdit(index: Int)
        case settings
    }
    
    private enum Layout {
        static let utilityButtonSize: CGFloat = 48
    }
    
    private enum Section { case main }
    
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, ButtonConfig>.SingleCellType<ButtonCell>
    
    private enum ElementKind: String {
        case pencilBadge
    }
    
    private let core: Core
    
    private let coordinationHandler: (HomeViewController, Coordination) -> Void
    
    private lazy var utilityButtonsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = isEditing
        return view
    }()
    
    private lazy var aboutButton = UIButton(systemImageName: "info.circle.fill",
                                            size: Layout.utilityButtonSize) { [weak self] _ in
        guard let self = self else { return }
        self.coordinationHandler(self, .about)
    }
    
    private lazy var editButton = UIButton(systemImageName: "pencil.circle.fill",
                                           size: Layout.utilityButtonSize) { [weak self] _ in
        guard let self = self else { return }
        self.isEditing = true
    }
    
    private lazy var settingsButton = UIButton(systemImageName: "gearshape.fill",
                                               size: Layout.utilityButtonSize) { [weak self] _ in
        guard let self = self else { return }
        self.coordinationHandler(self, .settings)
    }
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 64)
        label.textAlignment = .center
        label.textColor = .accent
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
                                        buttonCell.display(title: config.title)
                                        buttonCell.isHidden = config.isHidden
                                    })
        let pencilBadgeRegistration = UICollectionView.SupplementaryRegistration<PencilBadge>(elementKind: ElementKind.pencilBadge.rawValue) { [weak self] badge, _, indexPath in
            guard let self = self else { return }
            guard let config = self.buttonConfigs[safe: indexPath.item] else { return }
            badge.isHidden = config.isHidden || !self.isEditing
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    
    override var isEditing: Bool {
        didSet {
            guard oldValue != isEditing else { return }
            utilityButtonsContainer.isHidden = isEditing
            okButton.isHidden = !isEditing
            buttonConfigs.mutateEach { $1.isEditing = isEditing }
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private var buttonConfigs: [ButtonConfig] {
        didSet {
            guard oldValue != buttonConfigs else { return }
            displayButtonConfigs()
        }
    }
    
    private var publishResultDisplayer: [Int: () -> ()] = [:]
    private let buttonBusyIntervalMinimum: TimeInterval = 2
    
    private var bag = Set<AnyCancellable>()
    
    init(core: Core,
         coordinationHandler: @escaping (HomeViewController, Coordination) -> Void) {
        self.core = core
        self.coordinationHandler = coordinationHandler
        
        buttonConfigs = core.dataStore.settings.actions.map { _ in
            .init(title: "",
                  isEditing: false,
                  isHidden: false,
                  state: .normal)
        }
        super.init(nibName: nil, bundle: nil)
        setupLayouts()
        displayButtonConfigs()
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
            aboutButton
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        buttonConfigs.mutateEach { $1.state = .normal }
        
        core.$connectError
            .combineLatest(core.$state)
            .receive(on: DispatchQueue.main)
            .map { (connectError, state) -> (ButtonCell.State, String?) in
                switch state {
                case .disconnected: return (.disabled, connectError?.homeViewControllerErrorMessage)
                case .connecting: return (.disabled, "connecting...")
                case .connected: return (.normal, nil)
                }
            }
            .sink { [weak self] buttonCellState, errorMessage in
                guard let self = self else { return }
                self.buttonConfigs.mutateEach { $1.state = buttonCellState }
                self.errorMessageTextView.text = errorMessage
            }
            .store(in: &bag)
        
        core.dataStore.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self = self else { return }
                
                self.titleLabel.text = settings.homeTitle
                
                self.buttonConfigs.mutateEach {
                    guard let action = settings.actions[safe: $0] else { return }
                    $1.title = action.title
                    $1.isEditing = self.isEditing
                    $1.isHidden = settings.isUnusedButtonHidden && action.isEmpty
                }
            }
            .store(in: &bag)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        bag.removeAll()
    }
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isEditing else {
            coordinationHandler(self, .actionEdit(index: indexPath.item))
            return
        }
        
        handleButtonSelected(buttonConfigIndex: indexPath.item)
    }
    
    private func handleButtonSelected(buttonConfigIndex: Int) {
        guard let buttonConfig = buttonConfigs[safe: buttonConfigIndex],
              let action = core.dataStore.settings.actions[safe: buttonConfigIndex] else { return }
        
        guard buttonConfig.state != .busy,
              buttonConfig.state != .disabled else { return }
        
        buttonConfigs[safe: buttonConfigIndex]?.state = .busy
        errorMessageTextView.text = nil
        
        // Add a placeholder publishResultDisplayer
        publishResultDisplayer[buttonConfigIndex] = {}
        Timer.scheduledTimer(withTimeInterval: buttonBusyIntervalMinimum, repeats: false) { _ in
            guard let actionResultDisplayer = self.publishResultDisplayer[buttonConfigIndex] else { return }
            self.publishResultDisplayer[buttonConfigIndex] = nil
            actionResultDisplayer()
        }
        
        core.publish(message: action.message,
                     to: action.topic)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] in
                guard let self = self else { return }
                
                let publishError = $0.getError()
                
                let publishResultDisplayer = {
                    self.errorMessageTextView.text = (publishError == nil) ? nil : publishError!.homeViewControllerErrorMessage
                    self.buttonConfigs[safe: buttonConfigIndex]?.state = (publishError == nil) ? .success : .failure
                    
                    let soundEffect: SoundEffect = (publishError == nil) ? .success : .failure
                    soundEffect.play()
                }
                
                let displayImmediately = self.isSettingsError(publishError)
                if displayImmediately {
                    self.publishResultDisplayer[buttonConfigIndex] = nil
                    publishResultDisplayer()
                    return
                }
                
                let displayWhenButtonBusyIntervalMinimumReached = (self.publishResultDisplayer[buttonConfigIndex] != nil)
                if displayWhenButtonBusyIntervalMinimumReached {
                    self.publishResultDisplayer[buttonConfigIndex] = publishResultDisplayer
                    return
                }
                
                publishResultDisplayer()
            }, receiveValue: { _ in })
            .store(in: &bag)
    }
    
    private func isSettingsError(_ error: Error?) -> Bool {
        guard let error = error else { return false }
        
        if let connectError = error as? SMPMQTTClient.ConnectError {
            switch connectError {
            case .endpointEmpty,
                 .certificateEmpty,
                 .privateKeyEmpty,
                 .clientCertificatesCreateFailure: return true
            }
        }
        
        if let publishError = error as? SMPMQTTClient.PublishError {
            switch publishError {
            case .messageEmpty,
                 .topicEmpty,
                 .clientNotConnected: return true
            case .messageDropped,
                 .timeout: return false
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
        if let connectError = self as? SMPMQTTClient.ConnectError {
            switch connectError {
            case .endpointEmpty: return "MQTT endpoint empty"
            case .certificateEmpty: return "certificate empty"
            case .privateKeyEmpty: return "private key empty"
            case .clientCertificatesCreateFailure: return "certificate or private key incorrect"
            }
        }
        
        if let publishError = self as? SMPMQTTClient.PublishError {
            switch publishError {
            case .messageEmpty: return "message empty"
            case .topicEmpty: return "MQTT topic empty"
            case .clientNotConnected: return "client not connected"
            case .messageDropped: return "message dropped"
            case .timeout: return "timeout"
            }
        }
        
        if let corePublishError = self as? Core.PublishError {
            switch corePublishError {
            case .clientNotConnected(let connectError):
                return (connectError == nil) ?
                    "client not connected" :
                    connectError!.homeViewControllerErrorMessage
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
