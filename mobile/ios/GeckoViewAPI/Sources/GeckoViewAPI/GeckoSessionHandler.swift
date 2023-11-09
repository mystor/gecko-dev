// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import GeckoViewSupport

protocol GeckoSessionHandlerCommon : EventListener {
    var moduleName: String { get }
    var events: [String] { get }
    var enabled: Bool { get }
}

class GeckoSessionHandler<Delegate> : GeckoSessionHandlerCommon {
    let moduleName: String
    let events: [String]

    private(set) weak var session: GeckoSession?
    private var registeredListeners: Bool = false
    var delegate: Delegate? {
        didSet {
            if let sess = session {
                if (!registeredListeners && delegate != nil) {
                    for event in events {
                        sess.dispatcher.addListener(type: event, listener: self)
                    }
                    registeredListeners = true
                }

                // If session is not open, we will update module state during session opening.
                if (!sess.isOpen()) {
                    return;
                }

                let message: [String: Any] = [
                    "module": moduleName,
                    "enabled": delegate != nil,
                ]
                sess.dispatcher.dispatch(type: "GeckoView:UpdateModuleState", message: message)
            }
        }
    }

    var enabled : Bool {
        get { delegate != nil }
    }

    init(moduleName: String, events: [String], session: GeckoSession) {
        self.moduleName = moduleName
        self.events = events
        self.session = session
    }

    func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        if callback != nil {
            callback?.sendError("no handler registered")
        }
    }
}
