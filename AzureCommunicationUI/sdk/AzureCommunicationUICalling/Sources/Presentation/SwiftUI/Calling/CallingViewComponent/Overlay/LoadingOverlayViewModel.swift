//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import Combine
import Foundation

class LoadingOverlayViewModel: OverlayViewModelProtocol {
    private let localizationProvider: LocalizationProviderProtocol
    private let accessibilityProvider: AccessibilityProviderProtocol
    private let store: Store<AppState, Action>
    private var callingStatus: CallingStatus = .none
    private var operationStatus: OperationStatus = .skipSetupRequested
    private var audioPermission: AppPermission.Status = .unknown
    private var callType: CompositeCallType
    /* <CUSTOM_COLOR_FEATURE> */
    let themeOptions: ThemeOptions
    /* </CUSTOM_COLOR_FEATURE> */
    var cancellables = Set<AnyCancellable>()
    var networkManager: NetworkManager
    var audioSessionManager: AudioSessionManagerProtocol
    init(localizationProvider: LocalizationProviderProtocol,
         accessibilityProvider: AccessibilityProviderProtocol,
         networkManager: NetworkManager,
         audioSessionManager: AudioSessionManagerProtocol,
         /* <CUSTOM_COLOR_FEATURE> */
         themeOptions: ThemeOptions,
         /* </CUSTOM_COLOR_FEATURE> */
         store: Store<AppState, Action>,
         callType: CompositeCallType
    ) {
        self.localizationProvider = localizationProvider
        self.accessibilityProvider = accessibilityProvider
        self.networkManager = networkManager
        self.networkManager.startMonitor()
        self.audioSessionManager = audioSessionManager
        self.store = store
        self.audioPermission = store.state.permissionState.audioPermission
        self.callType = callType
        /* <CUSTOM_COLOR_FEATURE> */
        self.themeOptions = themeOptions
        /* </CUSTOM_COLOR_FEATURE> */
        store.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.receive(state)
            }.store(in: &cancellables)
    }

    deinit {
        networkManager.stopMonitor()
    }

    var title: String {
        return localizationProvider.getLocalizedString(.joiningCall)
    }

    var subtitle: String = ""

    @Published var isDisplayed = false

    func receive(_ state: AppState) {
        let permissionState = state.permissionState
        let callingState = state.callingState
        callingStatus = callingState.status
        operationStatus = callingState.operationStatus
        let shouldDisplay = operationStatus == .skipSetupRequested &&
        ((callingStatus == .connecting || callingStatus == .none) && callType != .oneToNOutgoing)

        if shouldDisplay != isDisplayed {
            isDisplayed = shouldDisplay
            accessibilityProvider.moveFocusToFirstElement()
        }

        if permissionState.audioPermission == .denied {
            store.dispatch(action: .errorAction(.fatalErrorUpdated(
                internalError: .callJoinFailedByMicPermission, error: nil)))
        }
    }
    func handleOffline() {
        guard networkManager.isConnected else {
            if operationStatus == .skipSetupRequested {
                store.dispatch(action: .errorAction(
                    .fatalErrorUpdated(internalError: .networkConnectionNotAvailable, error: nil)))
            }
            return
        }
    }
    func handleMicAvailabilityCheck() {
        guard audioSessionManager.isAudioUsedByOther() else {
            store.dispatch(action: .errorAction(
                .fatalErrorUpdated(internalError: .micNotAvailable, error: nil)))
            return
        }
    }
}
