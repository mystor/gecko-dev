// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import GeckoViewSupport

protocol EventListener {
    func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?)
}

class EventDispatcher : NSObject, SwiftEventDispatcher {
    var gecko: GeckoEventDispatcher? = nil
    var listeners: [String: EventListener] = [:]

    override init() {}

    public func addListener(type: String, listener: EventListener) {
        listeners[type] = listener
    }

    public func dispatch(type: String, message: [String: Any?]? = nil, callback: EventCallback? = nil) {
        if let listener = listeners[type] {
            listener.handleMessage(type: type, message: message, callback: callback)
        } else {
            gecko?.dispatch(toGecko: type, message: message, callback: callback)
        }
    }

    public enum Reply {
        case Success(Any?)
        case Error(Any?)
    }

    public func query(type: String, message: [String: Any?]? = nil) async -> Reply {
        class AsyncCallback : NSObject, EventCallback {
            let continuation: CheckedContinuation<Reply, Never>
            init(_ continuation: CheckedContinuation<Reply, Never>) {
                self.continuation = continuation
            }
            func sendSuccess(_ response: Any!) {
                continuation.resume(returning: .Success(response))
            }
            func sendError(_ response: Any!) {
                continuation.resume(returning: .Error(response))
            }
        }

        return await withCheckedContinuation({
            dispatch(type: type, message: message, callback: AsyncCallback($0))
        })
    }

    func attach(_ dispatcher: GeckoEventDispatcher?) {
        gecko = dispatcher
    }

    func dispatch(toSwift type: String, message: Any?, callback: EventCallback?) {
        let m = message as! [String: Any?]?
        if let listener = listeners[type] {
            listener.handleMessage(type: type, message: m, callback: callback)
        }
    }

    func hasListener(_ type: String) -> Bool {
        listeners.keys.contains(type)
    }
}
