/* -*- Mode: c++; c-basic-offset: 2; tab-width: 4; indent-tabs-mode: nil; -*-
 * vim: set sw=2 ts=4 expandtab:
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// This file contains implementations of the interfaces defined in
// `mobile/ios/GeckoViewAPI/Sources/GeckoViewSupport/include/GeckoViewSupport.h`

#include "AndroidView.h"
#import "GeckoViewSupport.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "nsIAppWindow.h"
#include "nsIWindowWatcher.h"
#include "nsPIDOMWindow.h"
#include "nsWindow.h"

#include "application.ini.h"

// NOTE: This is a temporary way to support content processes on the iOS
// simulator - I expect that we'll need an alternative approach on real
// devices.
#include "../../../ipc/contentproc/plugin-container.cpp"

/**
 * Return true if |arg| matches the given argument name.
 */
static bool IsArg(const char* arg, const char* s) {
  if (*arg == '-') {
    if (*++arg == '-') ++arg;
    return !strcasecmp(arg, s);
  }
  return false;
}

int GeckoViewMain(int argc, char** argv, NSString* principalClassName,
                  NSString* delegateClassName) {
  auto bootstrap = mozilla::GetBootstrap();
  if (bootstrap.isErr()) {
    fprintf(stderr, "Couldn't load XPCOM.\n");
    return 255;
  }

  // We are launching as a content process, delegate to the appropriate
  // main
  if (argc > 1 && IsArg(argv[1], "contentproc")) {
    // Set the process type. We don't remove the arg here as that will be done
    // later in common code.
    mozilla::SetGeckoProcessType(argv[argc - 1]);

    return content_process_main(bootstrap.inspect().get(), argc, argv);
  }

  mozilla::BootstrapConfig config;
  config.appData = &sAppData;
  config.appDataPath = nullptr;

  bootstrap.inspect()->XRE_EnableSameExecutableForContentProc();
  return bootstrap.inspect()->XRE_main(argc, argv, config);
}

@interface GeckoViewWindowImpl : NSObject <GeckoViewWindow> {
 @public
  RefPtr<nsWindow> mWindow;
  nsCOMPtr<nsPIDOMWindowOuter> mOuterWindow;
}

@end

@implementation GeckoViewWindowImpl

- (UIView*)view {
  return mWindow ? (UIView*)mWindow->GetNativeData(NS_NATIVE_WIDGET) : nil;
}

- (void)close {
  if (mWindow) {
    if (mWindow->GetAndroidView()) {
      mWindow->GetAndroidView()->mEventDispatcher->Detach();
    }
    mWindow = nullptr;
  }

  if (mOuterWindow) {
    mOuterWindow->ForceClose();
    mOuterWindow = nullptr;
  }
}

@end

id<GeckoViewWindow> GeckoViewOpenWindow(NSString* aId,
                                        id<SwiftEventDispatcher> aDispatcher,
                                        id aInitData) {
  nsAutoCString url;
  nsresult rv =
      mozilla::Preferences::GetCString("toolkit.defaultChromeURI", url);
  if (NS_FAILED(rv)) {
    url = "chrome://geckoview/content/geckoview.xhtml"_ns;
  }

  nsDependentCString id([aId UTF8String],
                        [aId lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);

  nsCOMPtr<nsIWindowWatcher> ww = do_GetService(NS_WINDOWWATCHER_CONTRACTID);
  MOZ_RELEASE_ASSERT(ww);

  // Prepare an nsIAndroidView to pass as argument to the window.
  RefPtr<mozilla::widget::AndroidView> androidView =
      new mozilla::widget::AndroidView();
  androidView->mEventDispatcher->Attach(aDispatcher, nullptr);
  androidView->mInitData = [aInitData retain];

  nsAutoCString chromeFlags("chrome,dialog=0,remote,resizable,scrollbars");
  // if (aPrivateMode) {
  //   chromeFlags += ",private";
  // }
  nsCOMPtr<mozIDOMWindowProxy> domWindow;
  ww->OpenWindow(nullptr, url, id, chromeFlags, androidView,
                 getter_AddRefs(domWindow));
  MOZ_RELEASE_ASSERT(domWindow);

  GeckoViewWindowImpl* window = [[GeckoViewWindowImpl alloc] init];

  window->mOuterWindow = nsPIDOMWindowOuter::From(domWindow);
  window->mWindow = nsWindow::From(window->mOuterWindow);
  MOZ_RELEASE_ASSERT(window->mWindow);

  window->mWindow->SetAndroidView(androidView);

  if (nsIWidgetListener* widgetListener =
          window->mWindow->GetWidgetListener()) {
    if (nsIAppWindow* appWindow = widgetListener->GetAppWindow()) {
      // The size of this window is forced by our embedder, so tell AppWindow
      // to not set a size for us.
      appWindow->SetIntrinsicallySized(false);
    }
  }

  return [window autorelease];
}
