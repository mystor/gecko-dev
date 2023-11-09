/* -*- Mode: c++; c-basic-offset: 2; tab-width: 20; indent-tabs-mode: nil; -*-
 * vim: set sw=2 ts=4 expandtab:
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "EventDispatcher.h"

#import "GeckoViewSupport.h"

#include "nsAppShell.h"
#include "nsGlobalWindowInner.h"
#include "nsJSUtils.h"
#include "js/Array.h"  // JS::GetArrayLength, JS::IsArrayObject, JS::NewArrayObject
#include "js/PropertyAndElement.h"  // JS_Enumerate, JS_GetElement, JS_GetProperty, JS_GetPropertyById, JS_SetElement, JS_SetUCProperty
#include "js/String.h"              // JS::StringHasLatin1Chars
#include "js/Warnings.h"            // JS::WarnUTF8
#include "nsObjCExceptions.h"
#include "xpcpublic.h"

#include "mozilla/fallible.h"
#include "mozilla/ScopeExit.h"
#include "mozilla/dom/ScriptSettings.h"
#include "mozilla/dom/ToJSValue.h"

namespace mozilla::widget::detail {

static void GetStringForNSString(const NSString* aSrc, nsAString& aDist) {
  NS_OBJC_BEGIN_TRY_IGNORE_BLOCK;

  if (!aSrc) {
    aDist.SetIsVoid(true);
    return;
  }

  aDist.SetLength([aSrc length]);
  [aSrc getCharacters:reinterpret_cast<unichar*>(aDist.BeginWriting())
                range:NSMakeRange(0, [aSrc length])];

  NS_OBJC_END_TRY_IGNORE_BLOCK;
}

static NSString* NSStringForString(const nsString& aSrc) {
  return [[[NSString alloc]
      initWithCharacters:reinterpret_cast<const unichar*>(aSrc.BeginReading())
                  length:aSrc.Length()] autorelease];
}

static NSString* NSStringForString(const char16_t* aSrc) {
  return [[[NSString alloc]
      initWithCharacters:reinterpret_cast<const unichar*>(aSrc)
                  length:NS_strlen(aSrc)] autorelease];
}

bool CheckJS(JSContext* aCx, bool aResult) {
  if (!aResult) {
    JS_ClearPendingException(aCx);
  }
  return aResult;
}

nsresult BoxString(JSContext* aCx, JS::Handle<JS::Value> aData,
                   id& aOut) {
  if (aData.isNullOrUndefined()) {
    aOut = nil;
    return NS_OK;
  }

  MOZ_ASSERT(aData.isString());

  JS::Rooted<JSString*> str(aCx, aData.toString());

  nsAutoJSString autoStr;
  NS_ENSURE_TRUE(CheckJS(aCx, autoStr.init(aCx, str)), NS_ERROR_FAILURE);
  aOut = NSStringForString(autoStr);
  if (!aOut) {
    return NS_ERROR_FAILURE;
  }
  return NS_OK;
}

nsresult BoxValue(JSContext* aCx, JS::Handle<JS::Value> aData,
                   id& aOut);

nsresult BoxObject(JSContext* aCx, JS::Handle<JS::Value> aData,
                   id& aOut);

nsresult BoxByteArray(JSContext* aCx, JS::Handle<JSObject*> aData,
                      id& aOut) {
  JS::AutoCheckCannotGC nogc;
  bool isShared = false;
  const void* data = JS_GetArrayBufferViewData(aData, &isShared, nogc);
  size_t length = JS_GetArrayBufferViewByteLength(aData);

  aOut = [NSData dataWithBytes:data length:length];
  if (!aOut) {
    return NS_ERROR_FAILURE;
  }
  return NS_OK;
}

nsresult BoxArray(JSContext* aCx, JS::Handle<JSObject*> aData,
                  id& aOut) {
  uint32_t length = 0;
  NS_ENSURE_TRUE(CheckJS(aCx, JS::GetArrayLength(aCx, aData, &length)),
                 NS_ERROR_FAILURE);

  NSMutableArray* arr = [NSMutableArray arrayWithCapacity:length];

  id elt = nil;
  JS::Rooted<JS::Value> element(aCx);
  for (size_t i = 1; i < length; i++) {
    NS_ENSURE_TRUE(CheckJS(aCx, JS_GetElement(aCx, aData, i, &element)),
                   NS_ERROR_FAILURE);
    nsresult rv = BoxValue(aCx, element, elt);
    NS_ENSURE_SUCCESS(rv, rv);
    [arr addObject:elt];
  }

  aOut = arr;
  return NS_OK;
}

nsresult BoxValue(JSContext* aCx, JS::Handle<JS::Value> aData,
                  id& aOut);

nsresult BoxObject(JSContext* aCx, JS::Handle<JS::Value> aData,
                   id& aOut) {
  if (aData.isNullOrUndefined()) {
    aOut = nullptr;
    return NS_OK;
  }

  MOZ_ASSERT(aData.isObject());

  JS::Rooted<JS::IdVector> ids(aCx, JS::IdVector(aCx));
  JS::Rooted<JSObject*> obj(aCx, &aData.toObject());

  bool isArray = false;
  if (CheckJS(aCx, JS::IsArrayObject(aCx, obj, &isArray)) && isArray) {
    return BoxArray(aCx, obj, aOut);
  }

  if (JS_IsTypedArrayObject(obj)) {
    return BoxByteArray(aCx, obj, aOut);
  }

  NS_ENSURE_TRUE(CheckJS(aCx, JS_Enumerate(aCx, obj, &ids)), NS_ERROR_FAILURE);

  const size_t length = ids.length();
  NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithCapacity:length];

  // Iterate through each property of the JS object.
  for (size_t i = 0; i < ids.length(); i++) {
    nsAutoJSString autoStr;
    NS_ENSURE_TRUE(CheckJS(aCx, autoStr.init(aCx, ids[i])), NS_ERROR_FAILURE);

    JS::Rooted<JS::Value> val(aCx);
    NS_ENSURE_TRUE(CheckJS(aCx, JS_GetPropertyById(aCx, obj, ids[i], &val)), NS_ERROR_FAILURE);

    id value = nil;
    nsresult rv = BoxValue(aCx, val, value);
    if (rv == NS_ERROR_INVALID_ARG && !JS_IsExceptionPending(aCx)) {
      JS_ReportErrorUTF8(aCx, "Invalid event data property %s",
                          NS_ConvertUTF16toUTF8(autoStr).get());
    }
    NS_ENSURE_SUCCESS(rv, rv);

    // Dictionaries cannot contain nil values, so they are converted to `NSNull` instead.
    if (value == nil) {
      value = [NSNull null];
    }
    [dict setValue:value forKey:NSStringForString(autoStr)];
  }

  aOut = dict;
  return NS_OK;
}

nsresult BoxValue(JSContext* aCx, JS::Handle<JS::Value> aData,
                  id& aOut) {
  if (aData.isNullOrUndefined()) {
    aOut = nil;
  } else if (aData.isBoolean()) {
    aOut = [NSNumber numberWithBool:aData.toBoolean()];
  } else if (aData.isInt32()) {
    aOut = [NSNumber numberWithInt:aData.toInt32()];
  } else if (aData.isNumber()) {
    aOut = [NSNumber numberWithDouble:aData.toNumber()];
  } else if (aData.isString()) {
    return BoxString(aCx, aData, aOut);
  } else if (aData.isObject()) {
    return BoxObject(aCx, aData, aOut);
  } else {
    NS_WARNING("Unknown type");
    return NS_ERROR_INVALID_ARG;
  }
  return NS_OK;
}

nsresult BoxData(JSContext* aCx, JS::Handle<JS::Value> aData,
                 id& aOut, bool aObjectOnly) {
  nsresult rv = NS_ERROR_INVALID_ARG;

  if (!aObjectOnly) {
    rv = detail::BoxValue(aCx, aData, aOut);
  } else if (aData.isObject() || aData.isNullOrUndefined()) {
    rv = detail::BoxObject(aCx, aData, aOut);
  }

  return rv;
}

nsresult BoxData(const nsAString& aEvent, JSContext* aCx,
                 JS::Handle<JS::Value> aData, id& aOut, bool aObjectOnly) {
  nsresult rv = BoxData(aCx, aData, aOut, aObjectOnly);
  if (rv != NS_ERROR_INVALID_ARG) {
    return rv;
  }

  NS_ConvertUTF16toUTF8 event(aEvent);
  if (JS_IsExceptionPending(aCx)) {
    JS::WarnUTF8(aCx, "Error dispatching %s", event.get());
  } else {
    JS_ReportErrorUTF8(aCx, "Invalid event data for %s", event.get());
  }
  return NS_ERROR_INVALID_ARG;
}

nsresult UnboxValue(JSContext* aCx, id aData,
                    JS::MutableHandle<JS::Value> aOut);

nsresult UnboxDictionary(JSContext* aCx, NSDictionary* aData,
                         JS::MutableHandle<JS::Value> aOut) {
  if (!aData) {
    aOut.set(JS::NullValue());
    return NS_OK;
  }
  JS::RootedObject obj(aCx, JS_NewPlainObject(aCx));
  for (NSString* key in aData) {
    nsAutoString strKey;
    GetStringForNSString(key, strKey);
    JS::RootedValue value(aCx);
    nsresult rv = UnboxValue(aCx, aData[key], &value);
    NS_ENSURE_SUCCESS(rv, rv);
    JS_SetUCProperty(aCx, obj, strKey.get(), strKey.Length(), value);
  }
  aOut.setObject(*obj);
  return NS_OK;
}

nsresult UnboxValue(JSContext* aCx, id aData,
                    JS::MutableHandle<JS::Value> aOut) {
  if (!aData || [aData isKindOfClass:[NSNull class]]) {
    aOut.set(JS::NullValue());
  } else if ([aData isKindOfClass:[NSString class]]) {
    nsAutoString strVal;
    GetStringForNSString((NSString*)aData, strVal);
    if (!mozilla::dom::ToJSValue(aCx, strVal, aOut)) {
      return NS_ERROR_FAILURE;
    }
  } else if ([aData isKindOfClass:[NSNumber class]]) {
    // If the type being held by the NSNumber is a BOOL set js value
    // to boolean. Otherwise use a double value.
    if (strcmp([(NSNumber*)aData objCType], @encode(BOOL)) == 0) {
      if (!mozilla::dom::ToJSValue(aCx, [(NSNumber*)aData boolValue], aOut)) {
        return NS_ERROR_FAILURE;
      }
    } else {
      if (!mozilla::dom::ToJSValue(aCx, [(NSNumber*)aData doubleValue], aOut)) {
        return NS_ERROR_FAILURE;
      }
    }
  } else if ([aData isKindOfClass:[NSArray class]]) {
    NSArray* objArr = (NSArray*)aData;

    JS::RootedVector<JS::Value> v(aCx);
    if (!v.resize([objArr count])) {
      return NS_ERROR_FAILURE;
    }
    for (size_t i = 0; i < [objArr count]; ++i) {
      nsresult rv = UnboxValue(aCx, objArr[i], v[i]);
      NS_ENSURE_SUCCESS(rv, rv);
    }

    JSObject* arrayObj = JS::NewArrayObject(aCx, v);
    if (!arrayObj) {
      return NS_ERROR_FAILURE;
    }
    aOut.setObject(*arrayObj);
  } else if ([aData isKindOfClass:[NSDictionary class]]) {
    JS::RootedObject obj(aCx, JS_NewPlainObject(aCx));
    for (NSString* key in aData) {
      nsAutoString strKey;
      GetStringForNSString(key, strKey);
      JS::RootedValue value(aCx);
      nsresult rv = UnboxValue(aCx, aData[key], &value);
      NS_ENSURE_SUCCESS(rv, rv);
      JS_SetUCProperty(aCx, obj, strKey.get(), strKey.Length(), value);
    }
    aOut.setObject(*obj);
  } else {
    NS_WARNING("Invalid type");
    return NS_ERROR_INVALID_ARG;
  }
  return NS_OK;
}

nsresult UnboxData(NSString* aEvent, JSContext* aCx, id aData,
                   JS::MutableHandle<JS::Value> aOut, bool aBundleOnly) {
  MOZ_ASSERT(NS_IsMainThread());

  if (aBundleOnly && aData && ![aData isKindOfClass:[NSDictionary class]]) {
    return NS_ERROR_INVALID_ARG;
  }

  nsresult rv = UnboxValue(aCx, aData, aOut);
  if (rv != NS_ERROR_INVALID_ARG || !aEvent) {
    return rv;
  }

  nsString event;
  GetStringForNSString(aEvent, event);
  if (JS_IsExceptionPending(aCx)) {
    JS::WarnUTF8(aCx, "Error dispatching %s",
                 NS_ConvertUTF16toUTF8(event).get());
  } else {
    JS_ReportErrorUTF8(aCx, "Invalid event data for %s",
                       NS_ConvertUTF16toUTF8(event).get());
  }
  return NS_ERROR_INVALID_ARG;
}

class SwiftCallbackDelegate final : public nsIAndroidEventCallback {
  id<EventCallback> mCallback;

  virtual ~SwiftCallbackDelegate() { [mCallback release]; }

  NS_IMETHOD Call(JSContext* aCx, JS::Handle<JS::Value> aData, SEL aSelector) {
    MOZ_ASSERT(NS_IsMainThread());

    id data;
    nsresult rv = BoxData(u"callback"_ns, aCx, aData, data,
                          /* ObjectOnly */ false);
    NS_ENSURE_SUCCESS(rv, rv);

    dom::AutoNoJSAPI nojsapi;

    [mCallback performSelector:aSelector withObject:data];
    return NS_OK;
  }

 public:
  explicit SwiftCallbackDelegate(id<EventCallback> aCallback)
      : mCallback(aCallback) {
    [aCallback retain];
  }

  NS_DECL_ISUPPORTS

  NS_IMETHOD OnSuccess(JS::Handle<JS::Value> aData, JSContext* aCx) override {
    return Call(aCx, aData, @selector(sendSuccess:));
  }

  NS_IMETHOD OnError(JS::Handle<JS::Value> aData, JSContext* aCx) override {
    return Call(aCx, aData, @selector(sendError:));
  }
};

NS_IMPL_ISUPPORTS(SwiftCallbackDelegate, nsIAndroidEventCallback)

class FinalizingCallbackDelegate final : public nsIAndroidEventCallback {
  const nsCOMPtr<nsIAndroidEventCallback> mCallback;
  const nsCOMPtr<nsIAndroidEventFinalizer> mFinalizer;

  virtual ~FinalizingCallbackDelegate() {
    if (mFinalizer) {
      mFinalizer->OnFinalize();
    }
  }

 public:
  FinalizingCallbackDelegate(nsIAndroidEventCallback* aCallback,
                             nsIAndroidEventFinalizer* aFinalizer)
      : mCallback(aCallback), mFinalizer(aFinalizer) {}

  NS_DECL_ISUPPORTS
  NS_FORWARD_NSIANDROIDEVENTCALLBACK(mCallback->);
};

NS_IMPL_ISUPPORTS(FinalizingCallbackDelegate, nsIAndroidEventCallback)

struct FinalizerCalledOnDtor {
  nsCOMPtr<nsIAndroidEventFinalizer> mFinalizer;
  ~FinalizerCalledOnDtor() {
    if (mFinalizer) {
      mFinalizer->OnFinalize();
    }
  }
};

}  // namespace mozilla::widget::detail

@interface NativeCallbackDelegateSupport : NSObject <EventCallback> {
  nsCOMPtr<nsIAndroidEventCallback> mCallback;
  mozilla::widget::detail::FinalizerCalledOnDtor mFinalizer;
  nsCOMPtr<nsIGlobalObject> mGlobalObject;
}

- (id)initWithCallback:(nsIAndroidEventCallback*)callback
             finalizer:(nsIAndroidEventFinalizer*)finalizer
          globalObject:(nsIGlobalObject*)globalObject;

- (void)sendSuccess:(id)response;
- (void)sendError:(id)response;
@end

@implementation NativeCallbackDelegateSupport
- (id)initWithCallback:(nsIAndroidEventCallback*)callback
             finalizer:(nsIAndroidEventFinalizer*)finalizer
          globalObject:(nsIGlobalObject*)globalObject {
  self = [super init];
  mCallback = callback;
  mFinalizer = {finalizer};
  mGlobalObject = globalObject;
  return self;
}
- (void)sendSuccess:(id)response {
  MOZ_ASSERT(NS_IsMainThread());

  // Use either the attached window's realm or a default realm.

  mozilla::dom::AutoJSAPI jsapi;
  NS_ENSURE_TRUE_VOID(jsapi.Init(mGlobalObject));

  JS::Rooted<JS::Value> data(jsapi.cx());
  nsresult rv = mozilla::widget::detail::UnboxData(@"callback", jsapi.cx(),
                                                   response, &data,
                                                   /* BundleOnly */ false);
  NS_ENSURE_SUCCESS_VOID(rv);

  rv = mCallback->OnSuccess(data, jsapi.cx());
  NS_ENSURE_SUCCESS_VOID(rv);
}
- (void)sendError:(id)response {
  MOZ_ASSERT(NS_IsMainThread());

  // Use either the attached window's realm or a default realm.

  mozilla::dom::AutoJSAPI jsapi;
  NS_ENSURE_TRUE_VOID(jsapi.Init(mGlobalObject));

  JS::Rooted<JS::Value> data(jsapi.cx());
  nsresult rv = mozilla::widget::detail::UnboxData(@"callback", jsapi.cx(),
                                                   response, &data,
                                                   /* BundleOnly */ false);
  NS_ENSURE_SUCCESS_VOID(rv);

  rv = mCallback->OnError(data, jsapi.cx());
  NS_ENSURE_SUCCESS_VOID(rv);
}
@end

@interface EventDispatcherImpl : NSObject <GeckoEventDispatcher> {
  RefPtr<mozilla::widget::EventDispatcher> mDispatcher;
}

- (id)initWithDispatcher:(mozilla::widget::EventDispatcher*)dispatcher;

@end

@implementation EventDispatcherImpl

- (id)initWithDispatcher:(mozilla::widget::EventDispatcher*)dispatcher {
  self = [super init];
  self->mDispatcher = dispatcher;
  return self;
}

- (void)dispatchToGecko:(NSString *)type message:(id)message callback:(id<EventCallback>)callback {
  mDispatcher->DispatchToGecko((CFStringRef)type, message, callback);
}

- (BOOL)hasListener:(NSString *)type {
  return mDispatcher->HasGeckoListener((CFStringRef)type);
}

@end

namespace mozilla::widget {

using namespace detail;

NS_IMPL_ISUPPORTS(EventDispatcher, nsIAndroidEventDispatcher)

nsIGlobalObject* EventDispatcher::GetGlobalObject() {
  if (mDOMWindow) {
    return nsGlobalWindowInner::Cast(mDOMWindow->GetCurrentInnerWindow());
  }
  return xpc::NativeGlobal(xpc::PrivilegedJunkScope());
}

nsresult EventDispatcher::DispatchOnGecko(ListenersList* list,
                                          const nsAString& aEvent,
                                          JS::Handle<JS::Value> aData,
                                          nsIAndroidEventCallback* aCallback) {
  MOZ_ASSERT(NS_IsMainThread());
  dom::AutoNoJSAPI nojsapi;

  list->lockCount++;

  auto iteratingScope = MakeScopeExit([list] {
    list->lockCount--;
    if (list->lockCount || !list->unregistering) {
      return;
    }

    list->unregistering = false;
    for (ssize_t i = list->listeners.Count() - 1; i >= 0; i--) {
      if (list->listeners[i]) {
        continue;
      }
      list->listeners.RemoveObjectAt(i);
    }
  });

  const size_t count = list->listeners.Count();
  for (size_t i = 0; i < count; i++) {
    if (!list->listeners[i]) {
      // Unregistered.
      continue;
    }
    const nsresult rv = list->listeners[i]->OnEvent(aEvent, aData, aCallback);
    Unused << NS_WARN_IF(NS_FAILED(rv));
  }
  return NS_OK;
}

id EventDispatcher::WrapCallback(nsIAndroidEventCallback* aCallback,
                                 nsIAndroidEventFinalizer* aFinalizer) {
  if (!aCallback) {
    return nil;
  }

  return [[NativeCallbackDelegateSupport alloc]
      initWithCallback:aCallback
             finalizer:aFinalizer
          globalObject:GetGlobalObject()];
}

bool EventDispatcher::HasListener(const char16_t* aEvent) {
  return [mDispatcher hasListener:NSStringForString(aEvent)];
}

NS_IMETHODIMP
EventDispatcher::Dispatch(JS::Handle<JS::Value> aEvent,
                          JS::Handle<JS::Value> aData,
                          nsIAndroidEventCallback* aCallback,
                          nsIAndroidEventFinalizer* aFinalizer,
                          JSContext* aCx) {
  MOZ_ASSERT(NS_IsMainThread());

  if (!aEvent.isString()) {
    NS_WARNING("Invalid event name");
    return NS_ERROR_INVALID_ARG;
  }

  nsAutoJSString event;
  NS_ENSURE_TRUE(CheckJS(aCx, event.init(aCx, aEvent.toString())),
                 NS_ERROR_OUT_OF_MEMORY);

  // Don't need to lock here because we're on the main thread, and we can't
  // race against Register/UnregisterListener.

  ListenersList* list = mListenersMap.Get(event);
  if (list) {
    if (!aCallback || !aFinalizer) {
      return DispatchOnGecko(list, event, aData, aCallback);
    }
    nsCOMPtr<nsIAndroidEventCallback> callback(
        new FinalizingCallbackDelegate(aCallback, aFinalizer));
    return DispatchOnGecko(list, event, aData, callback);
  }

  id<SwiftEventDispatcher> dispatcher = (id<SwiftEventDispatcher>)mDispatcher;
  if (!dispatcher) {
    return NS_OK;
  }

  id data;
  nsresult rv = BoxData(event, aCx, aData, data, /* ObjectOnly */ true);
  // Keep XPConnect from overriding the JSContext exception with one
  // based on the nsresult.
  //
  // XXXbz Does xpconnect still do that?  Needs to be checked/tested.
  NS_ENSURE_SUCCESS(rv, JS_IsExceptionPending(aCx) ? NS_OK : rv);

  dom::AutoNoJSAPI nojsapi;
  [dispatcher dispatchToSwift:NSStringForString(event)
                      message:data
                     callback:WrapCallback(aCallback, aFinalizer)];
  return NS_OK;
}

nsresult EventDispatcher::Dispatch(const char16_t* aEvent,
                                   id aData,
                                   nsIAndroidEventCallback* aCallback) {
  nsDependentString event(aEvent);

  ListenersList* list = mListenersMap.Get(event);
  if (list) {
    dom::AutoJSAPI jsapi;
    NS_ENSURE_TRUE(jsapi.Init(GetGlobalObject()), NS_ERROR_FAILURE);
    JS::Rooted<JS::Value> data(jsapi.cx());
    nsresult rv = UnboxData(/* Event */ nullptr, jsapi.cx(), aData, &data,
                            /* BundleOnly */ true);
    NS_ENSURE_SUCCESS(rv, rv);
    return DispatchOnGecko(list, event, data, aCallback);
  }

  id<SwiftEventDispatcher> dispatcher = (id<SwiftEventDispatcher>)mDispatcher;
  if (!dispatcher) {
    return NS_OK;
  }

  [dispatcher dispatchToSwift:NSStringForString(event) message:aData callback:WrapCallback(aCallback)];
  return NS_OK;
}

nsresult EventDispatcher::IterateEvents(JSContext* aCx,
                                        JS::Handle<JS::Value> aEvents,
                                        IterateEventsCallback aCallback,
                                        nsIAndroidEventListener* aListener) {
  MOZ_ASSERT(NS_IsMainThread());

  MutexAutoLock lock(mLock);

  auto processEvent = [this, aCx, aCallback,
                       aListener](JS::Handle<JS::Value> event) -> nsresult {
    nsAutoJSString str;
    NS_ENSURE_TRUE(CheckJS(aCx, str.init(aCx, event.toString())),
                   NS_ERROR_OUT_OF_MEMORY);
    return (this->*aCallback)(str, aListener);
  };

  if (aEvents.isString()) {
    return processEvent(aEvents);
  }

  bool isArray = false;
  NS_ENSURE_TRUE(aEvents.isObject(), NS_ERROR_INVALID_ARG);
  NS_ENSURE_TRUE(CheckJS(aCx, JS::IsArrayObject(aCx, aEvents, &isArray)),
                 NS_ERROR_INVALID_ARG);
  NS_ENSURE_TRUE(isArray, NS_ERROR_INVALID_ARG);

  JS::Rooted<JSObject*> events(aCx, &aEvents.toObject());
  uint32_t length = 0;
  NS_ENSURE_TRUE(CheckJS(aCx, JS::GetArrayLength(aCx, events, &length)),
                 NS_ERROR_INVALID_ARG);
  NS_ENSURE_TRUE(length, NS_ERROR_INVALID_ARG);

  for (size_t i = 0; i < length; i++) {
    JS::Rooted<JS::Value> event(aCx);
    NS_ENSURE_TRUE(CheckJS(aCx, JS_GetElement(aCx, events, i, &event)),
                   NS_ERROR_INVALID_ARG);
    NS_ENSURE_TRUE(event.isString(), NS_ERROR_INVALID_ARG);

    const nsresult rv = processEvent(event);
    NS_ENSURE_SUCCESS(rv, rv);
  }
  return NS_OK;
}

nsresult EventDispatcher::RegisterEventLocked(
    const nsAString& aEvent, nsIAndroidEventListener* aListener) {
  ListenersList* list = mListenersMap.GetOrInsertNew(aEvent);

#ifdef DEBUG
  for (ssize_t i = 0; i < list->listeners.Count(); i++) {
    NS_ENSURE_TRUE(list->listeners[i] != aListener,
                   NS_ERROR_ALREADY_INITIALIZED);
  }
#endif

  list->listeners.AppendObject(aListener);
  return NS_OK;
}

NS_IMETHODIMP
EventDispatcher::RegisterListener(nsIAndroidEventListener* aListener,
                                  JS::Handle<JS::Value> aEvents,
                                  JSContext* aCx) {
  return IterateEvents(aCx, aEvents, &EventDispatcher::RegisterEventLocked,
                       aListener);
}

nsresult EventDispatcher::UnregisterEventLocked(
    const nsAString& aEvent, nsIAndroidEventListener* aListener) {
  ListenersList* list = mListenersMap.Get(aEvent);
#ifdef DEBUG
  NS_ENSURE_TRUE(list, NS_ERROR_NOT_INITIALIZED);
#else
  NS_ENSURE_TRUE(list, NS_OK);
#endif

  DebugOnly<bool> found = false;
  for (ssize_t i = list->listeners.Count() - 1; i >= 0; i--) {
    if (list->listeners[i] != aListener) {
      continue;
    }
    if (list->lockCount) {
      // Only mark for removal when list is locked.
      list->listeners.ReplaceObjectAt(nullptr, i);
      list->unregistering = true;
    } else {
      list->listeners.RemoveObjectAt(i);
    }
    found = true;
  }
#ifdef DEBUG
  return found ? NS_OK : NS_ERROR_NOT_INITIALIZED;
#else
  return NS_OK;
#endif
}

NS_IMETHODIMP
EventDispatcher::UnregisterListener(nsIAndroidEventListener* aListener,
                                    JS::Handle<JS::Value> aEvents,
                                    JSContext* aCx) {
  return IterateEvents(aCx, aEvents, &EventDispatcher::UnregisterEventLocked,
                       aListener);
}

void EventDispatcher::Attach(id aDispatcher,
                             nsPIDOMWindowOuter* aDOMWindow) {
  MOZ_ASSERT(NS_IsMainThread());
  MOZ_ASSERT(aDispatcher);

  id<SwiftEventDispatcher> prevDispatcher = (id<SwiftEventDispatcher>)mDispatcher;
  id<SwiftEventDispatcher> newDispatcher = (id<SwiftEventDispatcher>)aDispatcher;

  if (prevDispatcher && prevDispatcher == newDispatcher) {
    // Only need to update the window.
    mDOMWindow = aDOMWindow;
    return;
  }

  [prevDispatcher attach:nil];
  [prevDispatcher release];

  mDispatcher = [newDispatcher retain];

  // FIXME: ACTUALLY ATTACH THIS WHEEE
  EventDispatcherImpl* proxy = [[EventDispatcherImpl alloc] initWithDispatcher: this];
  [newDispatcher attach:[proxy autorelease]];

  mDOMWindow = aDOMWindow;
}

void EventDispatcher::Shutdown() {
  if (mDispatcher) {
    [mDispatcher release];
  }
  mDispatcher = nullptr;
  mDOMWindow = nullptr;
}

void EventDispatcher::Detach() {
  MOZ_ASSERT(NS_IsMainThread());
  MOZ_ASSERT(mDispatcher);


  // SetAttachedToGecko will call disposeNative for us later on the Gecko
  // thread to make sure all pending dispatchToGecko calls have completed.
  if (mDispatcher) {
    [(id<SwiftEventDispatcher>)mDispatcher attach:nil];
  }

  Shutdown();
}

bool EventDispatcher::HasGeckoListener(CFStringRef aEvent) {
  // Can be called from any thread.
  MutexAutoLock lock(mLock);
  nsAutoString s;
  GetStringForNSString((NSString*)aEvent, s);
  return !!mListenersMap.Get(s);
}

void EventDispatcher::DispatchToGecko(CFStringRef aEvent,
                                      id aData,
                                      id aCallback) {
  MOZ_ASSERT(NS_IsMainThread());

  // Don't need to lock here because we're on the main thread, and we can't
  // race against Register/UnregisterListener.

  nsString event;
  GetStringForNSString((NSString*)aEvent, event);
  ListenersList* list = mListenersMap.Get(event);
  if (!list || list->listeners.IsEmpty()) {
    return;
  }

  // Use the same compartment as the attached window if possible, otherwise
  // use a default compartment.
  dom::AutoJSAPI jsapi;
  NS_ENSURE_TRUE_VOID(jsapi.Init(GetGlobalObject()));

  JS::Rooted<JS::Value> data(jsapi.cx());
  nsresult rv = UnboxData((NSString*)aEvent, jsapi.cx(), aData, &data,
                          /* BundleOnly */ true);
  NS_ENSURE_SUCCESS_VOID(rv);

  nsCOMPtr<nsIAndroidEventCallback> callback;
  if (aCallback) {
    callback =
        new SwiftCallbackDelegate(aCallback);
  }

  DispatchOnGecko(list, event, data, callback);
}

/* static */
nsresult EventDispatcher::UnboxBundle(JSContext* aCx, id aData,
                                      JS::MutableHandle<JS::Value> aOut) {
  if (aData && ![aData isKindOfClass:[NSDictionary class]]) {
    return NS_ERROR_INVALID_ARG;
  }

  return detail::UnboxValue(aCx, aData, aOut);
}

}  // namespace mozilla::widget
