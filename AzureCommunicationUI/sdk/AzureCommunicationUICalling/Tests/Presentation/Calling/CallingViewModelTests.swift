//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation
import XCTest
import AzureCommunicationCommon

@testable import AzureCommunicationUICalling

class CallingViewModelTests: XCTestCase {
    var factoryMocking: CompositeViewModelFactoryMocking!
    var storeFactory: StoreFactoryMocking!
    var cancellable: CancelBag!
    var logger: LoggerMocking!
    var localizationProvider: LocalizationProviderMocking!
    var accessibilityProvider: AccessibilityProviderMocking!
    var capabilitiesManager: CapabilitiesManager!
    var rendererViewManager: RendererViewManager!

    private let timeout: TimeInterval = 10.0

    override func setUp() {
        super.setUp()
        cancellable = CancelBag()
        logger = LoggerMocking()
        storeFactory = StoreFactoryMocking()
        localizationProvider = LocalizationProviderMocking()
        accessibilityProvider = AccessibilityProviderMocking()

        factoryMocking = CompositeViewModelFactoryMocking(logger: logger,
                                                          store: storeFactory.store,
                                                          accessibilityProvider: accessibilityProvider,
                                                          localizationProvider: localizationProvider,
                                                          avatarManager: AvatarViewManagerMocking(
                                                            store: storeFactory.store,
                                                            localParticipantId: createCommunicationIdentifier(fromRawId: ""),
                                                          localParticipantViewData: nil),
                                                          updatableOptionsManager: UpdatableOptionsManager(store: storeFactory.store, setupScreenOptions: nil, callScreenOptions: nil))
        capabilitiesManager = CapabilitiesManager(callType: .groupCall)
        rendererViewManager = VideoViewManager(callingSDKWrapper: CallingSDKWrapperMocking(), logger: logger)
    }

    override func tearDown() {
        super.tearDown()
        cancellable = nil
        storeFactory = nil
        localizationProvider = nil
        accessibilityProvider = nil
        logger = nil
        factoryMocking = nil
        rendererViewManager = nil
    }

    func test_callingViewModel_update_when_callStatusIsInLobby_then_isLobbyOverlayDisplayed_shouldBecomeTrue() {
        let sut = makeSUT()
        let appState = AppState(callingState: CallingState(status: .inLobby))
        sut.receive(appState)
        XCTAssert(sut.lobbyOverlayViewModel.isDisplayed)
    }

    func test_callingViewModel_update_when_callStatusIsConnected_then_isLobbyOverlayDisplayed_shouldBecomeFalse() {
        let sut = makeSUT()
        let appState = AppState(callingState: CallingState(status: .connected))
        sut.receive(appState)
        XCTAssertFalse(sut.lobbyOverlayViewModel.isDisplayed)
    }

    func test_callingViewModel_update_when_lifeCycleStateIsBackground_callStatusIsInLobby_then_isLobbyOverlayDisplayed_shouldKeepSame() {
        let sut = makeSUT()
        let originalState = sut.lobbyOverlayViewModel.isDisplayed
        let appState = AppState(callingState: CallingState(status: .inLobby),
                                visibilityState: VisibilityState(currentStatus: .hidden))
        sut.receive(appState)
        XCTAssertEqual(sut.lobbyOverlayViewModel.isDisplayed, originalState)
    }

    func test_callingViewModel_update_when_callStatusIsConnected_remoteParticipantNotEmpty_then_isParticipantGridDisplayed_shouldBecomeTrue() {
        let sut = makeSUT()
        let mockingParticipantInfoModel = ParticipantInfoModelBuilder.get()
        let remoteParticipantState = RemoteParticipantsState(participantInfoList: [mockingParticipantInfoModel],
                                                             lastUpdateTimeStamp: Date())
        let appState = AppState(callingState: CallingState(status: .connected),
                                remoteParticipantsState: remoteParticipantState)
        sut.receive(appState)
        XCTAssertEqual(sut.isParticipantGridDisplayed, true)
    }

    func test_callingViewModel_update_when_callStatusIsRinging_remoteParticipantNotEmpty_then_isParticipantGridDisplayed_shouldBecomeTrue() {
        let sut = makeSUT(callType: .oneToNOutgoing)
        let mockingParticipantInfoModel = ParticipantInfoModelBuilder.get()
        let remoteParticipantState = RemoteParticipantsState(participantInfoList: [mockingParticipantInfoModel],
                                                             lastUpdateTimeStamp: Date())
        let appState = AppState(callingState: CallingState(status: .ringing),
                                remoteParticipantsState: remoteParticipantState)
        sut.receive(appState)
        XCTAssertEqual(sut.isParticipantGridDisplayed, true)
    }

    func test_callingViewModel_update_when_callStatusIsConnecting_remoteParticipantNotEmpty_then_isParticipantGridDisplayed_shouldBecomeTrue() {
        let sut = makeSUT(callType: .oneToNOutgoing)
        let mockingParticipantInfoModel = ParticipantInfoModelBuilder.get()
        let remoteParticipantState = RemoteParticipantsState(participantInfoList: [mockingParticipantInfoModel],
                                                             lastUpdateTimeStamp: Date())
        let appState = AppState(callingState: CallingState(status: .connecting),
                                remoteParticipantsState: remoteParticipantState)
        sut.receive(appState)
        XCTAssertEqual(sut.isParticipantGridDisplayed, true)
    }

    func test_callingViewModel_update_when_callStatusIsNotConnected_remoteParticipantNotEmpty_then_isParticipantGridDisplayed_shouldBecomeFalse() {
        let sut = makeSUT()
        let mockingParticipantInfoModel = ParticipantInfoModelBuilder.get()
        let remoteParticipantState = RemoteParticipantsState(participantInfoList: [mockingParticipantInfoModel],
                                                             lastUpdateTimeStamp: Date())
        let appState = AppState(callingState: CallingState(status: .inLobby),
                                remoteParticipantsState: remoteParticipantState)
        sut.receive(appState)
        XCTAssertEqual(sut.isParticipantGridDisplayed, false)
    }

    func test_callingViewModel_update_when_callStatusIsNotConnected_remoteParticipantEmpty_then_isParticipantGridDisplayed_shouldBecomeFalse() {
        let sut = makeSUT()
        let remoteParticipantState = RemoteParticipantsState(participantInfoList: [],
                                                             lastUpdateTimeStamp: Date())
        let appState = AppState(callingState: CallingState(status: .connected),
                                remoteParticipantsState: remoteParticipantState)
        sut.receive(appState)
        XCTAssertEqual(sut.isParticipantGridDisplayed, false)
    }

    func test_callingViewModel_receive_when_statusUpdated_then_controlBarViewModelUpdated() {
        let expectation = XCTestExpectation(description: "ControlBarViewModel is updated")
        let appState = AppState(permissionState: PermissionState(audioPermission: .granted),
                                localUserState: LocalUserState(displayName: "DisplayName"))
        let updateControlBarViewModel: (LocalUserState, PermissionState, VisibilityState, ButtonViewDataState) -> Void = { userState, permissionState, _, _ in
            XCTAssertEqual(appState.localUserState.displayName, userState.displayName)
            XCTAssertEqual(appState.permissionState.audioPermission, permissionState.audioPermission)
            expectation.fulfill()
        }
        factoryMocking.controlBarViewModel = ControlBarViewModelMocking(compositeViewModelFactory: factoryMocking,
                                                                        logger: logger,
                                                                        localizationProvider: localizationProvider,
                                                                        dispatchAction: storeFactory.store.dispatch,
                                                                        onEndCallTapped: {},
                                                                        localUserState: storeFactory.store.state.localUserState,
                                                                        updateState: updateControlBarViewModel,
                                                                        capabilitiesManager: capabilitiesManager,
                                                                        accessibilityProvider: accessibilityProvider,
                                                                        buttonViewDataState: storeFactory.store.state.buttonViewDataState)
        let sut = makeSUT()
        sut.receive(appState)
        wait(for: [expectation], timeout: timeout)
    }

    func test_callingViewModel_receive_when_statusUpdated_then_infoHeaderViewModelUpdated() {
        let expectation = XCTestExpectation(description: "InfoHeaderViewModel is updated")
        let date = Calendar.current.date(
            byAdding: .minute,
            value: -1,
            to: Date())!
        let appState = AppState(callingState: CallingState(status: .connected),
                                localUserState: LocalUserState(displayName: "DisplayName"),
                                remoteParticipantsState: RemoteParticipantsState(lastUpdateTimeStamp: date))
        let updateInfoHeaderViewModel: (LocalUserState, RemoteParticipantsState, CallingState, VisibilityState) -> Void = { userState, remoteParticipantsState, callingState, _ in
            XCTAssertEqual(appState.localUserState.displayName, userState.displayName)
            XCTAssertEqual(appState.remoteParticipantsState.lastUpdateTimeStamp, remoteParticipantsState.lastUpdateTimeStamp)
            XCTAssertEqual(appState.callingState.status, callingState.status)
            expectation.fulfill()
        }

        factoryMocking.infoHeaderViewModel = InfoHeaderViewModelMocking(
                                                                        compositeViewModelFactory: factoryMocking,
                                                                        logger: logger,
                                                                        localUserState: storeFactory.store.state.localUserState,
                                                                        accessibilityProvider: accessibilityProvider,
                                                                        dispatchAction: storeFactory.store.dispatch,
                                                                        updateState: updateInfoHeaderViewModel)

        let sut = makeSUT()
        sut.receive(appState)
        wait(for: [expectation], timeout: timeout)
    }

    func test_callingViewModel_receive_when_statusUpdated_then_localVideoViewModelUpdated() {
        let expectation = XCTestExpectation(description: "LocalVideoViewModel is updated")
        let appState = AppState(localUserState: LocalUserState(displayName: "DisplayName"))
        let updateLocalVideoViewModel: (LocalUserState, VisibilityState) -> Void = { userState, _ in
            XCTAssertEqual(appState.localUserState.displayName, userState.displayName)
            expectation.fulfill()
        }
        factoryMocking.localVideoViewModel = LocalVideoViewModelMocking(
                                                                        compositeViewModelFactory: factoryMocking,
                                                                        logger: logger,
                                                                        localizationProvider: localizationProvider,
                                                                        dispatchAction: storeFactory.store.dispatch,
                                                                        updateState: updateLocalVideoViewModel)

        let sut = makeSUT()
        sut.receive(appState)
        wait(for: [expectation], timeout: timeout)
    }

    func test_callingViewModel_receive_when_statusUpdated_then_participantGridViewModelUpdated() {
        let expectation = XCTestExpectation(description: "ParticipantGridViewModel is updated")
        let appState = AppState()
        let updateParticipantGridViewModel: (CallingState, RemoteParticipantsState, VisibilityState, LifeCycleState) -> Void = { _, remoteParticipantsState, _, _ in
            XCTAssertEqual(appState.remoteParticipantsState.lastUpdateTimeStamp, remoteParticipantsState.lastUpdateTimeStamp)
            expectation.fulfill()
        }
        factoryMocking.participantGridViewModel = ParticipantGridViewModelMocking(
                                                                                  compositeViewModelFactory: factoryMocking,
                                                                                  localizationProvider: localizationProvider,
                                                                                  accessibilityProvider: accessibilityProvider,
                                                                                  updateState: updateParticipantGridViewModel,
                                                                                  rendererViewManager: rendererViewManager)

        let sut = makeSUT()
        sut.receive(appState)
        wait(for: [expectation], timeout: timeout)
    }

    func test_callingViewModel_receive_when_statusUpdated_then_bannerViewModelUpdated() {
        let expectation = XCTestExpectation(description: "BannerViewModel is updated")
        let appState = AppState(callingState: CallingState(status: .connected))
        let updateBannerViewModel: (CallingState, VisibilityState) -> Void = { callingState, _ in
            XCTAssertEqual(appState.callingState.status, callingState.status)
            expectation.fulfill()
        }
        factoryMocking.bannerViewModel = BannerViewModelMocking(compositeViewModelFactory: factoryMocking,
                                                                dispatchAction: storeFactory.store.dispatch,
                                                                updateState: updateBannerViewModel)
        let sut = makeSUT()
        sut.receive(appState)
        wait(for: [expectation], timeout: timeout)
    }

    func test_callingViewModel_receive_when_callingStateStatusUpdated_then_accessibilityFocusUpdated() {
        let expectation = XCTestExpectation(description: "Accessibility focus is updated")
        let appState = AppState(callingState: CallingState(status: .inLobby))
        let moveFocusToFirstElementBlock: () -> Void = {
            expectation.fulfill()
        }
        accessibilityProvider.moveFocusToFirstElementBlock = moveFocusToFirstElementBlock
        let sut = makeSUT()
        sut.receive(appState)
        wait(for: [expectation], timeout: timeout)
    }

    func test_callingViewModel_receive_when_callingStateStatusIsLocalHold_then_isOnHoldOverlayDisplayed_shouldBeTrue() {
        let sut = makeSUT()
        let appState = AppState(callingState: CallingState(status: .localHold))
        sut.receive(appState)
        XCTAssertTrue(sut.onHoldOverlayViewModel.isDisplayed)
    }

    func test_callingViewModel_update_when_callingStateStatusIsConnected_then_isOnHoldOverlayDisplayed_shouldBeFalse() {
        let sut = makeSUT()
        let appState = AppState(callingState: CallingState(status: .connected))
        sut.receive(appState)
        XCTAssertFalse(sut.lobbyOverlayViewModel.isDisplayed)
    }

    func test_callingViewModel_receive_when_statusUpdated_then_onHoldOverlayViewModelUpdated() {
        let expectation = XCTestExpectation(description: "OnHoldOverlayViewModel is updated")
        let appState = AppState(callingState: CallingState(status: .localHold))

        let updateOnHoldOverlayViewModel: (CallingStatus) -> Void = { callingStatus in
            XCTAssertEqual(appState.callingState.status, callingStatus)
            expectation.fulfill()
        }
        factoryMocking.onHoldOverlayViewModel = OnHoldOverlayViewModelMocking(localizationProvider: localizationProvider,
                                                                              compositeViewModelFactory: factoryMocking,
                                                                              logger: logger,
                                                                              accessibilityProvider: accessibilityProvider,
                                                                              audioSessionManager: AudioSessionManager(store: storeFactory.store, logger: logger,
                                                                                                                       isCallKitEnabled: false),
                                                                              resumeAction: {},
                                                                              updateState: updateOnHoldOverlayViewModel)

        let sut = makeSUT()
        sut.receive(appState)
        wait(for: [expectation], timeout: timeout)
    }

    func test_callingViewModel_update_when_callStatusIsConnected_appStateForeground_then_switchToBackground_shouldBecomeBackground() {
        let sut = makeSUT()
        let appState = AppState(callingState: CallingState(status: .connected),
                                lifeCycleState: LifeCycleState(currentStatus: .background))
        sut.receive(appState)
        XCTAssertEqual(sut.appState, .background)
    }

    func test_callingViewModel_update_when_callStatusIsConnected_appStateBackground_then_switchToForeground_shouldBecomeForeground() {
        let sut = makeSUT()
        let appState = AppState(callingState: CallingState(status: .connected),
                                lifeCycleState: LifeCycleState(currentStatus: .foreground))
        sut.receive(appState)
        XCTAssertEqual(sut.appState, .foreground)
    }
}

extension CallingViewModelTests {
    func makeSUT(callType: CompositeCallType = .groupCall) -> CallingViewModel {
        return CallingViewModel(compositeViewModelFactory: factoryMocking,
                                store: storeFactory.store,
                                localizationProvider: LocalizationProvider(logger: logger),
                                accessibilityProvider: accessibilityProvider,
                                isIpadInterface: false,
                                allowLocalCameraPreview: true,
                                callType: callType,
                                captionsOptions: CaptionsOptions(),
                                capabilitiesManager: capabilitiesManager,
                                callScreenOptions: CallScreenOptions(),
                                rendererViewManager: rendererViewManager)
    }
}
