// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import GeckoViewSupport

/** Element details for onContextMenu callbacks. */
public struct ContextElement {
    public enum ElementType {
        case NONE, IMAGE, VIDEO, AUDIO
    }

    /** The base URI of the element's document. */
    public let baseUri: String?

    /** The absolute link URI (href) of the element. */
    public let linkUri: String?

    /** The title text of the element. */
    public let title: String?

    /** The alternative text (alt) for the element. */
    public let altText: String?

    /** The type of the element. One of the  flags. */
    public let type: ElementType

    /** The source URI (src) of the element. Set for (nested) media elements. */
    public let srcUri: String?

    /** The text content of the element */
    public let textContent: String?
}

public enum SlowScriptResponse {
    case STOP, CONTINUE
}

public protocol ContentDelegate {
    /**
     * A page title was discovered in the content or updated after the content loaded.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param title The title sent from the content.
     */
    func onTitleChange(session: GeckoSession, title: String)

    /**
     * A preview image was discovered in the content after the content loaded.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param previewImageUrl The preview image URL sent from the content.
     */
    func onPreviewImage(session: GeckoSession, previewImageUrl: String)

    /**
     * A page has requested focus. Note that window.focus() in content will not result in this being
     * called.
     *
     * @param session The GeckoSession that initiated the callback.
     */
    func onFocusRequest(session: GeckoSession)

    /**
     * A page has requested to close
     *
     * @param session The GeckoSession that initiated the callback.
     */
    func onCloseRequest(session: GeckoSession)

    /**
     * A page has entered or exited full screen mode. Typically, the implementation would set the
     * Activity containing the GeckoSession to full screen when the page is in full screen mode.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param fullScreen True if the page is in full screen mode.
     */
    func onFullScreen(session: GeckoSession, fullScreen: Bool)

    /**
     * A viewport-fit was discovered in the content or updated after the content.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param viewportFit The value of viewport-fit of meta element in content.
     * @see <a href="https://drafts.csswg.org/css-round-display/#viewport-fit-descriptor">4.1. The
     *     viewport-fit descriptor</a>
     */
    func onMetaViewportFitChange(session: GeckoSession, viewportFit: String)

    /**
     * Session is on a product url.
     *
     * @param session The GeckoSession that initiated the callback.
     */
    func onProductUrl(session: GeckoSession)


    /**
     * A user has initiated the context menu via long-press. This event is fired on links, (nested)
     * images and (nested) media elements.
     *
     * @param session The GeckoSession that initiated the callback.
     * @param screenX The screen coordinates of the press.
     * @param screenY The screen coordinates of the press.
     * @param element The details for the pressed element.
     */
    func onContextMenu(
        session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement)

    /**
     * This is fired when there is a response that cannot be handled by Gecko (e.g., a download).
     *
     * @param session the GeckoSession that received the external response.
     * @param response the external WebResponse.
     */
    // func onExternalResponse(session: GeckoSession, response: WebResponse)

    /**
     * The content process hosting this GeckoSession has crashed. The GeckoSession is now closed and
     * unusable. You may call {@link #open(GeckoRuntime)} to recover the session, but no state is
     * preserved. Most applications will want to call {@link #load} or {@link
     * #restoreState(SessionState)} at this point.
     *
     * @param session The GeckoSession for which the content process has crashed.
     */
    func onCrash(session: GeckoSession)

    /**
     * The content process hosting this GeckoSession has been killed. The GeckoSession is now closed
     * and unusable. You may call {@link #open(GeckoRuntime)} to recover the session, but no state
     * is preserved. Most applications will want to call {@link #load} or {@link
     * #restoreState(SessionState)} at this point.
     *
     * @param session The GeckoSession for which the content process has been killed.
     */
    func onKill(session: GeckoSession)

    /**
     * Notification that the first content composition has occurred. This callback is invoked for
     * the first content composite after either a start or a restart of the compositor.
     *
     * @param session The GeckoSession that had a first paint event.
     */
    func onFirstComposite(session: GeckoSession)

    /**
     * Notification that the first content paint has occurred. This callback is invoked for the
     * first content paint after a page has been loaded, or after a {@link
     * #onPaintStatusReset(GeckoSession)} event. The function {@link
     * #onFirstComposite(GeckoSession)} will be called once the compositor has started rendering.
     * However, it is possible for the compositor to start rendering before there is any content to
     * render. onFirstContentfulPaint() is called once some content has been rendered. It may be
     * nothing more than the page background color. It is not an indication that the whole page has
     * been rendered.
     *
     * @param session The GeckoSession that had a first paint event.
     */
    func onFirstContentfulPaint(session: GeckoSession)

    /**
     * Notification that the paint status has been reset.
     *
     * <p>This callback is invoked whenever the painted content is no longer being displayed. This
     * can occur in response to the session being paused. After this has fired the compositor may
     * continue rendering, but may not render the page content. This callback can therefore be used
     * in conjunction with {@link #onFirstContentfulPaint(GeckoSession)} to determine when there is
     * valid content being rendered.
     *
     * @param session The GeckoSession that had the paint status reset event.
     */
    func onPaintStatusReset(session: GeckoSession)

    /**
     * This is fired when the loaded document has a valid Web App Manifest present.
     *
     * <p>The various colors (theme_color, background_color, etc.) present in the manifest have been
     * transformed into #AARRGGBB format.
     *
     * @param session The GeckoSession that contains the Web App Manifest
     * @param manifest A parsed and validated {@link JSONObject} containing the manifest contents.
     * @see <a href="https://www.w3.org/TR/appmanifest/">Web App Manifest specification</a>
     */
    func onWebAppManifest(session: GeckoSession, manifest: Any)

    /**
     * A script has exceeded its execution timeout value
     *
     * @param geckoSession GeckoSession that initiated the callback.
     * @param scriptFileName Filename of the slow script
     * @return A {@link GeckoResult} with a SlowScriptResponse value which indicates whether to
     *     allow the Slow Script to continue processing. Stop will halt the slow script. Continue
     *     will pause notifications for a period of time before resuming.
     */
    func onSlowScript(session: GeckoSession, scriptFileName: String) async -> SlowScriptResponse

    /**
     * The app should display its dynamic toolbar, fully expanded to the height that was previously
     * specified via {@link GeckoView#setDynamicToolbarMaxHeight}.
     *
     * @param geckoSession GeckoSession that initiated the callback.
     */
    func onShowDynamicToolbar(session: GeckoSession)

    /**
     * This method is called when a cookie banner was detected.
     *
     * <p>Note: this method is called only if the cookie banner setting is such that allows to
     * handle the banner. For example, if cookiebanners.service.mode=1 (Reject only) but a cookie
     * banner can only be accepted on the website - the detection in that case won't be reported.
     * The exception is MODE_DETECT_ONLY mode, when only the detection event is emitted.
     *
     * @param session GeckoSession that initiated the callback.
     */
    func onCookieBannerDetected(session: GeckoSession)

    /**
     * This method is called when a cookie banner was handled.
     *
     * @param session GeckoSession that initiated the callback.
     */
    func onCookieBannerHandled(session: GeckoSession)
}

// All methods on ContentDelegate are optional, provide default implementations.
public extension ContentDelegate {
    func onTitleChange(session: GeckoSession, title: String) {}
    func onPreviewImage(session: GeckoSession, previewImageUrl: String) {}
    func onFocusRequest(session: GeckoSession) {}
    func onCloseRequest(session: GeckoSession) {}
    func onFullScreen(session: GeckoSession, fullScreen: Bool) {}
    func onMetaViewportFitChange(session: GeckoSession, viewportFit: String) {}
    func onProductUrl(session: GeckoSession) {}
    func onContextMenu(
        session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement) {}
    // func onExternalResponse(session: GeckoSession, response: WebResponse) {}
    func onCrash(session: GeckoSession) {}
    func onKill(session: GeckoSession) {}
    func onFirstComposite(session: GeckoSession) {}
    func onFirstContentfulPaint(session: GeckoSession) {}
    func onPaintStatusReset(session: GeckoSession) {}
    func onWebAppManifest(session: GeckoSession, manifest: Any) {}
    func onSlowScript(session: GeckoSession, scriptFileName: String) async -> SlowScriptResponse { .STOP }
    func onShowDynamicToolbar(session: GeckoSession) {}
    func onCookieBannerDetected(session: GeckoSession) {}
    func onCookieBannerHandled(session: GeckoSession) {}
}

class ContentHandler : GeckoSessionHandler<ContentDelegate> {
    init(session: GeckoSession) {
        super.init(
            moduleName: "GeckoViewContent",
            events: [
                "GeckoView:ContentCrash",
                "GeckoView:ContentKill",
                "GeckoView:ContextMenu",
                "GeckoView:DOMMetaViewportFit",
                "GeckoView:PageTitleChanged",
                "GeckoView:DOMWindowClose",
                "GeckoView:ExternalResponse",
                "GeckoView:FocusRequest",
                "GeckoView:FullScreenEnter",
                "GeckoView:FullScreenExit",
                "GeckoView:WebAppManifest",
                "GeckoView:FirstContentfulPaint",
                "GeckoView:PaintStatusReset",
                "GeckoView:PreviewImage",
                "GeckoView:CookieBannerEvent:Detected",
                "GeckoView:CookieBannerEvent:Handled",
                "GeckoView:SavePdf",
                "GeckoView:OnProductUrl",
            ],
            session: session)
    }

    override func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        let session = self.session!
        switch type {
        case "GeckoView:ContentCrash":
            session.close()
            delegate?.onCrash(session: session)
        case "GeckoView:ContentKill":
            session.close()
            delegate?.onKill(session: session)
        case "GeckoView:ContextMenu":
            func parseType(type: String) -> ContextElement.ElementType {
                switch type {
                case "HTMLImageElement": return .IMAGE
                case "HTMLVideoElement": return .VIDEO
                case "HTMLAudioElement": return .AUDIO
                default: return .NONE
                }
            }

            let contextElement = ContextElement(
                baseUri: message!["baseUri"] as? String,
                linkUri: message!["linkUri"] as? String,
                title: message!["title"] as? String,
                altText: message!["alt"] as? String,
                type: parseType(type: message!["elementType"] as! String),
                srcUri: message!["elementSrc"] as? String,
                textContent: message!["textContent"] as? String)

            delegate?.onContextMenu(
                session: session,
                screenX: message!["screenX"] as! Int,
                screenY: message!["screenY"] as! Int,
                element: contextElement)
        case "GeckoView:DOMMetaViewportFit":
            delegate?.onMetaViewportFitChange(session: session, viewportFit: message!["viewportfit"] as! String)
        case "GeckoView:PageTitleChanged":
            delegate?.onTitleChange(session: session, title: message!["title"] as! String)
        case "GeckoView:DOMWindowClose":
            delegate?.onCloseRequest(session: session)
        case "GeckoView:ExternalResponse":
            // FIXME: implement
            fatalError()
        case "GeckoView:FocusRequest":
            delegate?.onFocusRequest(session: session)
        case "GeckoView:FullScreenEnter":
            delegate?.onFullScreen(session: session, fullScreen: true)
        case "GeckoView:FullScreenExit":
            delegate?.onFullScreen(session: session, fullScreen: false)
        case "GeckoView:WebAppManifest":
            delegate?.onWebAppManifest(session: session, manifest: message!["manifest"]!!)
        case "GeckoView:FirstContentfulPaint":
            delegate?.onFirstContentfulPaint(session: session)
        case "GeckoView:PaintStatusReset":
            delegate?.onPaintStatusReset(session: session)
        case "GeckoView:PreviewImage":
            delegate?.onPreviewImage(session: session, previewImageUrl: message!["previewImageUrl"] as! String)
        case "GeckoView:CookieBannerEvent:Detected":
            delegate?.onCookieBannerDetected(session: session)
        case "GeckoView:CookieBannerEvent:Handled":
            delegate?.onCookieBannerHandled(session: session)
        case "GeckoView:SavePdf":
            // FIXME: implement
            fatalError()
        case "GeckoView:OnProductUrl":
            delegate?.onProductUrl(session: session)
        default:
            super.handleMessage(type: type, message: message, callback: callback)
        }
    }
}

class ProcessHangHandler : GeckoSessionHandler<ContentDelegate> {
    init(session: GeckoSession) {
        super.init(
            moduleName: "GeckoViewProcessHangMonitor",
            events: ["GeckoView:HangReport"],
            session: session)
    }

    override func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        let session = self.session!
        switch type {
        case "GeckoView:HangReport":
            let reportId = message!["hangId"] as! Int
            Task { @MainActor in
                let response = await delegate?.onSlowScript(session: session, scriptFileName: message!["scriptFileName"] as! String)
                switch response {
                case .CONTINUE:
                    session.dispatcher.dispatch(type: "GeckoView:HangReportWait", message: ["hangId": reportId])
                default:
                    session.dispatcher.dispatch(type: "GeckoView:HangReportStop", message: ["hangId": reportId])
                }
            }
        default:
            super.handleMessage(type: type, message: message, callback: callback)
        }
    }
}
