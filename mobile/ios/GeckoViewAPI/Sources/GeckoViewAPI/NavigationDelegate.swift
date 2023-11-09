// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import GeckoViewSupport

public enum ContentPermissionType : Int32 {
    /**
     * Permission for using the geolocation API. See:
     * https://developer.mozilla.org/en-US/docs/Web/API/Geolocation
     */
    case GEOLOCATION = 0

    /**
     * Permission for using the notifications API. See:
     * https://developer.mozilla.org/en-US/docs/Web/API/notification
     */
    case DESKTOP_NOTIFICATION = 1

    /**
     * Permission for using the storage API. See:
     * https://developer.mozilla.org/en-US/docs/Web/API/Storage_API
     */
    case PERSISTENT_STORAGE = 2

    /** Permission for using the WebXR API. See: https://www.w3.org/TR/webxr */
    case XR = 3

    /** Permission for allowing autoplay of inaudible (silent) video. */
    case AUTOPLAY_INAUDIBLE = 4

    /** Permission for allowing autoplay of audible video. */
    case AUTOPLAY_AUDIBLE = 5

    /** Permission for accessing system media keys used to decode DRM media. */
    case MEDIA_KEY_SYSTEM_ACCESS = 6

    /**
     * Permission for trackers to operate on the page -- disables all tracking protection features
     * for a given site.
     */
    case TRACKING = 7

    /**
     * Permission for third party frames to access first party cookies. May be granted heuristically
     * in some cases.
     */
    case STORAGE_ACCESS = 8
}

public enum ContentPermissionValue: Int32 {
    /** The corresponding permission is currently set to default/prompt behavior. */
    case PROMPT = 3
    /** The corresponding permission is currently set to deny. */
    case DENY = 2
    /** The corresponding permission is currently set to allow. */
    case ALLOW = 1
}

public struct ContentPermission {
    /** The URI associated with this content permission. */
    public let uri: String

    /**
     * The third party origin associated with the request; currently only used for storage access
     * permission.
     */
    public let thirdPartyOrigin: String?

    /**
     * A boolean indicating whether this content permission is associated with private browsing.
     */
    public let privateMode: Bool

    /** The type of this permission. */
    public let permission: ContentPermissionType;

    /** The value of the permission. */
    public let value: ContentPermissionValue;

    /**
     * The context ID associated with the permission if any.
     *
     * @see GeckoSessionSettings.Builder#contextId
     */
    public let contextId: String;

    let principal: String;
}

public enum LoadRequestTarget {
    case WINDOW_CURRENT, WINDOW_NEW
}

public struct LoadRequest {
    /** The URI to be loaded. */
    public let uri: String

    /**
     * The URI of the origin page that triggered the load request. null for initial loads and
     * loads originating from data: URIs.
     */
    public let triggerUri: String?

    /** The target where the window has requested to open. */
    public let target: LoadRequestTarget

    /**
     * True if and only if the request was triggered by an HTTP redirect.
     *
     * <p>If the user loads URI "a", which redirects to URI "b", then <code>onLoadRequest</code>
     * will be called twice, first with uri "a" and <code>isRedirect = false</code>, then with uri
     * "b" and <code>isRedirect = true</code>.
     */
    public let isRedirect: Bool

    /** True if there was an active user gesture when the load was requested. */
    public let hasUserGesture: Bool

    /**
     * This load request was initiated by a direct navigation from the application. E.g. when
     * calling {@link GeckoSession#load}.
     */
    public let isDirectNavigation: Bool
}

public protocol NavigationDelegate {
    /**
     * A view has started loading content from the network.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param url The resource being loaded.
     * @param perms The permissions currently associated with this url.
     */
    func onLocationChange(session: GeckoSession, url: String?, perms: [ContentPermission])

    /**
     * The view's ability to go back has changed.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param canGoBack The new value for the ability.
     */
    func onCanGoBack(session: GeckoSession, canGoBack: Bool)

    /**
     * The view's ability to go forward has changed.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param canGoForward The new value for the ability.
     */
    func onCanGoForward(session: GeckoSession, canGoForward: Bool)

    /**
     * A request to open an URI. This is called before each top-level page load to allow custom
     * behavior. For example, this can be used to override the behavior of TAGET_WINDOW_NEW
     * requests, which defaults to requesting a new GeckoSession via onNewSession.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param request The {@link LoadRequest} containing the request details.
     * @return A {@link GeckoResult} with a {@link AllowOrDeny} value which indicates whether or not
     *     the load was handled. If unhandled, Gecko will continue the load as normal. If handled (a
     *     {@link AllowOrDeny#DENY DENY} value), Gecko will abandon the load. A null return value is
     *     interpreted as {@link AllowOrDeny#ALLOW ALLOW} (unhandled).
     */
    func onLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny

    /**
     * A request to load a URI in a non-top-level context.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param request The {@link LoadRequest} containing the request details.
     * @return A {@link GeckoResult} with a {@link AllowOrDeny} value which indicates whether or not
     *     the load was handled. If unhandled, Gecko will continue the load as normal. If handled (a
     *     {@link AllowOrDeny#DENY DENY} value), Gecko will abandon the load. A null return value is
     *     interpreted as {@link AllowOrDeny#ALLOW ALLOW} (unhandled).
     */
    func onSubframeLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny

    /**
     * A request has been made to open a new session. The URI is provided only for informational
     * purposes. Do not call GeckoSession.load here. Additionally, the returned GeckoSession must be
     * a newly-created one.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param uri The URI to be loaded.
     * @return A {@link GeckoResult} which holds the returned GeckoSession. May be null, in which
     *     case the request for a new window by web content will fail. e.g., <code>window.open()
     *     </code> will return null. The implementation of onNewSession is responsible for
     *     maintaining a reference to the returned object, to prevent it from being garbage
     *     collected.
     */
    func onNewSession(session: GeckoSession, uri: String) async -> GeckoSession?

    /**
     * @param session The GeckoSession that initiated the callback.
     * @param uri The URI that failed to load.
     * @param error A WebRequestError containing details about the error
     * @return A URI to display as an error. Returning null will halt the load entirely. The
     *     following special methods are made available to the URI: -
     *     document.addCertException(isTemporary), returns Promise -
     *     document.getFailedCertSecurityInfo(), returns FailedCertSecurityInfo -
     *     document.getNetErrorInfo(), returns NetErrorInfo document.reloadWithHttpsOnlyException()
     * @see <a
     *     href="https://searchfox.org/mozilla-central/source/dom/webidl/FailedCertSecurityInfo.webidl">FailedCertSecurityInfo
     *     IDL</a>
     * @see <a
     *     href="https://searchfox.org/mozilla-central/source/dom/webidl/NetErrorInfo.webidl">NetErrorInfo
     *     IDL</a>
     */
    // func onLoadError(session: GeckoSession, uri: String?, error: WebRequestError) -> String?
}

// All methods on NavigationDelegate are optional, provide default implementations.
public extension NavigationDelegate {
    func onLocationChange(session: GeckoSession, url: String?, perms: [ContentPermission]) {}
    func onCanGoBack(session: GeckoSession, canGoBack: Bool) {}
    func onCanGoForward(session: GeckoSession, canGoForward: Bool) {}
    func onLoadRequest(session: GeckoSession, request: LoadRequest) -> AllowOrDeny { .ALLOW }
    func onSubframeLoadRequest(session: GeckoSession, request: LoadRequest) -> AllowOrDeny { .ALLOW }
    func onNewSession(session: GeckoSession, uri: String) -> GeckoSession? { nil }
    // func onLoadError(session: GeckoSession, uri: String?, error: WebRequestError) -> String? { nil }
}


class NavigationHandler : GeckoSessionHandler<NavigationDelegate> {
    init(session: GeckoSession) {
        super.init(
            moduleName: "GeckoViewNavigation",
            events: [
                "GeckoView:LocationChange",
                "GeckoView:OnNewSession",
                "GeckoView:OnLoadError",
                "GeckoView:OnLoadRequest",
            ],
            session: session)
    }

    override func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        let session = self.session!
        switch type {
        case "GeckoView:LocationChange":
            if message!["isTopLevel"] as! Bool {
                // let perms = message!["permissions"] as! [[String: Any?]]
                // FIXME: Convert permissions
                delegate?.onLocationChange(session: session, url: message!["uri"] as? String, perms: [])
            }
            delegate?.onCanGoBack(session: session, canGoBack: message!["canGoBack"] as! Bool)
            delegate?.onCanGoForward(session: session, canGoForward: message!["canGoForward"] as! Bool)

        case "GeckoView:OnNewSession":
            let newSessionId = message!["newSessionId"] as! String
            Task { @MainActor in
                if let result = await delegate?.onNewSession(session: session, uri: message!["uri"] as! String) {
                    assert(result.isOpen())
                    result.open(windowId: newSessionId)
                    callback?.sendSuccess(true)
                } else {
                    callback?.sendSuccess(false)
                }
            }

        case "GeckoView:OnLoadError":
            let uri = message!["uri"] as! String
            let errorCode = message!["error"] as! Int64
            let errorModule = message!["errorModule"] as! Int32
            let errorClass = message!["errorClass"] as! Int32
            break

        case "GeckoView:OnLoadRequest":
            func convertTarget(_ target: Int32) -> LoadRequestTarget {
                switch target {
                case 0:
                    return .WINDOW_CURRENT
                case 1:
                    return .WINDOW_CURRENT
                default:
                    return .WINDOW_NEW
                }
            }

            // Match with nsIWebNavigation.idl.
            let LOAD_REQUEST_IS_REDIRECT = 0x800000

            let loadRequest = LoadRequest(
                uri: message!["uri"] as! String,
                triggerUri: message!["triggerUri"] as? String,
                target: convertTarget(message!["where"] as! Int32),
                isRedirect: ((message!["flags"] as! Int) & LOAD_REQUEST_IS_REDIRECT) != 0,
                hasUserGesture: message!["hasUserGesture"] as! Bool,
                isDirectNavigation: true)

            Task { @MainActor in
                let result = await delegate?.onLoadRequest(session: session, request: loadRequest)
                callback?.sendSuccess(result == .ALLOW)
            }

        default:
            super.handleMessage(type: type, message: message, callback: callback)
        }
    }
}
