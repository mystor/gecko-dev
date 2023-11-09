// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import GeckoViewSupport

public class GeckoRuntime {
    public static func main(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>, principalClassName: String?, delegateClassName: String?) {
        GeckoViewMain(argc, argv, principalClassName, delegateClassName);
    }
}
