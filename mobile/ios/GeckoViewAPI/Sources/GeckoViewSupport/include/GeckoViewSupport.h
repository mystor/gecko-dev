/* -*- Mode: Objective-C; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* vim: set ts=8 sts=2 et sw=2 tw=80: */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define GECKOVIEW_EXPORT __attribute__((__visibility__("default")))

#ifdef __cplusplus
extern "C" {
#endif

GECKOVIEW_EXPORT int GeckoViewMain(int argc, char** argv,
                                   NSString* principalClassName,
                                   NSString* delegateClassName);

@protocol EventCallback <NSObject>
- (void)sendSuccess:(id)response;
- (void)sendError:(id)response;
@end

@protocol GeckoEventDispatcher <NSObject>
- (void)dispatchToGecko:(NSString*)type
                message:(id)message
               callback:(id<EventCallback>)callback;
- (BOOL)hasListener:(NSString*)type;
@end

@protocol SwiftEventDispatcher <NSObject>
- (void)attach:(id<GeckoEventDispatcher>)gecko;
- (void)dispatchToSwift:(NSString*)type
                message:(id)message
               callback:(id<EventCallback>)callback;
- (BOOL)hasListener:(NSString*)type;
@end

@protocol GeckoViewWindow <NSObject>
- (UIView*)view;
- (void)close;
@end

GECKOVIEW_EXPORT id<GeckoViewWindow> GeckoViewOpenWindow(
    NSString* aId, id<SwiftEventDispatcher> aDispatcher, id aInitData);

#ifdef __cplusplus
}
#endif

#undef GECKOVIEW_EXPORT
