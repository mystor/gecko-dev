// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import GeckoViewSupport

public protocol ProgressDelegate {
    /**
     * A View has started loading content from the network.
     *
     * @param session GeckoSession that initiated the callback.
     * @param url The resource being loaded.
     */
    func onPageStart(session: GeckoSession, url: String)

    /**
     * A View has finished loading content from the network.
     *
     * @param session GeckoSession that initiated the callback.
     * @param success Whether the page loaded successfully or an error occurred.
     */
    func onPageStop(session: GeckoSession, success: Bool)

    /**
     * Page loading has progressed.
     *
     * @param session GeckoSession that initiated the callback.
     * @param progress Current page load progress value [0, 100].
     */
    func onProgressChange(session: GeckoSession, progress: Int)

    /**
     * The security status has been updated.
     *
     * @param session GeckoSession that initiated the callback.
     * @param securityInfo The new security information.
     */
    // func onSecurityChange(session: GeckoSession, securityInfo: SecurityInformation)

    /**
     * The browser session state has changed. This can happen in response to navigation, scrolling,
     * or form data changes; the session state passed includes the most up to date information on
     * all of these.
     *
     * @param session GeckoSession that initiated the callback.
     * @param sessionState SessionState representing the latest browser state.
     */
    // func onSessionStateChange(session: GeckoSession, sessionState: SessionState)
}

// All methods on ProgressDelegate are optional, provide default implementations.
public extension ProgressDelegate {
    func onPageStart(session: GeckoSession, url: String) {}
    func onPageStop(session: GeckoSession, success: Bool) {}
    func onProgressChange(session: GeckoSession, progress: Int) {}
    // func onSecurityChange(session: GeckoSession, securityInfo: SecurityInformation) {}
    // func onSessionStateChange(session: GeckoSession, sessionState: SessionState) {}
}

class ProgressHandler : GeckoSessionHandler<ProgressDelegate> {
    init(session: GeckoSession) {
        super.init(
            moduleName: "GeckoViewProgress",
            events: [
                "GeckoView:PageStart",
                "GeckoView:PageStop",
                "GeckoView:ProgressChanged",
                "GeckoView:SecurityChanged",
                "GeckoView:StateUpdated",
            ],
            session: session)
    }

    override func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        let session = self.session!
        switch type {
        case "GeckoView:PageStart":
            delegate?.onPageStart(session: session, url: message!["uri"] as! String)
        case "GeckoView:PageStop":
            delegate?.onPageStop(session: session, success: message!["success"] as! Bool)
        case "GeckoView:ProgressChanged":
            delegate?.onProgressChange(session: session, progress: message!["progress"] as! Int)
        case "GeckoView:SecurityChanged":
            // TODO: Implement
            break
        case "GeckoView:StateUpdated":
            // TODO: Implement
            break
        default:
            super.handleMessage(type: type, message: message, callback: callback)
        }
    }
}
