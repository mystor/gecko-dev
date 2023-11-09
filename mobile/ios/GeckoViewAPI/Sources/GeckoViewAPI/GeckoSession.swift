// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import GeckoViewSupport

public class GeckoSession {
    let dispatcher: EventDispatcher = EventDispatcher()
    var window: GeckoViewWindow?
    var id: String?
    private(set) public var view: UIView?

    lazy var contentHandler: ContentHandler = ContentHandler(session: self)
    lazy var processHangHandler: ProcessHangHandler = ProcessHangHandler(session: self)
    public var contentDelegate: ContentDelegate? {
        get { contentHandler.delegate }
        set {
            contentHandler.delegate = newValue
            processHangHandler.delegate = newValue
        }
    }

    lazy var navigationHandler: NavigationHandler = NavigationHandler(session: self)
    public var navigationDelegate: NavigationDelegate? {
        get { navigationHandler.delegate }
        set { navigationHandler.delegate = newValue }
    }

    lazy var progressHandler: ProgressHandler = ProgressHandler(session: self)
    public var progressDelegate: ProgressDelegate? {
        get { progressHandler.delegate }
        set { progressHandler.delegate = newValue }
    }

    lazy var sessionHandlers: [GeckoSessionHandlerCommon] = [
        contentHandler,
        processHangHandler,
        navigationHandler,
        progressHandler,
    ]

    public init() {
        // Register handlers for all listeners.
        for sessionHandler in sessionHandlers {
            for type in sessionHandler.events {
                dispatcher.addListener(type: type, listener: sessionHandler)
            }
        }
    }

    public func open(windowId: String? = nil) {
        assert(!isOpen(), "cannot open a GeckoSession twice")

        id = windowId ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let settings: [String: Any?] = [
            "chromeUri": nil,
            "screenId": 0,
            "useTrackingProtection": false,
            "userAgentMode": /* USER_AGENT_MODE_MOBILE */ 0,
            "userAgentOverride": nil,
            "viewportMode": /* VIEWPORT_MODE_MOBILE */ 0,
            "displayMode": /* DISPLAY_MODE_BROWSER */ 0,
            "suspendMediaWhenInactive": false,
            "allowJavascript": true,
            "fullAccessibilityTree": false,
            "isPopup": false,
            "sessionContextId": nil,
            "unsafeSessionContextId": nil,
        ]
        let modules: [String: Bool] = Dictionary(uniqueKeysWithValues: sessionHandlers.map {
            ($0.moduleName, $0.enabled)
        })

        window = GeckoViewOpenWindow(id, dispatcher, [
            "settings": settings,
            "modules": modules,
        ])
        view = window?.view()
        view?.translatesAutoresizingMaskIntoConstraints = false
    }

    public func isOpen() -> Bool { window != nil }

    public func close() {
        window?.close()
        window = nil
    }

    public func load(_ url: URL) {
        dispatcher.dispatch(type: "GeckoView:LoadUri", message: [
            "uri": url.absoluteString,
            "flags": 0,
            "headerFilter": /* HEADER_FILTER_CORS_SAFELISTED */ 1,
        ])
    }

    public func reload() {
        dispatcher.dispatch(type: "GeckoView:Reload", message: [
            "flags": 0,
        ])
    }

    public func stop() {
        dispatcher.dispatch(type: "GeckoView:Stop")
    }

    public func goBack(userInteraction: Bool = true) {
        dispatcher.dispatch(type: "GeckoView:GoBack", message: [
            "userInteraction": userInteraction,
        ])
    }

    public func goForward(userInteraction: Bool = true) {
        dispatcher.dispatch(type: "GeckoView:GoForward", message: [
            "userInteraction": userInteraction,
        ])
    }

    public func getUserAgent() async -> String? {
        switch await dispatcher.query(type: "GeckoView:GetUserAgent") {
        case .Success(let result):
            return result as? String
        default:
            return nil
        }
    }

    public func setActive(_ active: Bool) {
        dispatcher.dispatch(type: "GeckoView:SetActive", message: ["active": active])
    }
}
