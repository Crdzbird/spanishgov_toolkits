//
//  CustomDnieCallbackHandler.h
//
//  Created by Arturo Carretero Calvo on 3/1/23.
//  Copyright © 2023. All rights reserved.
//

#include "J2ObjC_header.h"

#pragma push_macro("INCLUDE_ALL_CustomDnieCallbackHandler")
#ifdef RESTRICT_CustomDnieCallbackHandler
#define INCLUDE_ALL_CustomDnieCallbackHandler 0
#else
#define INCLUDE_ALL_CustomDnieCallbackHandler 1
#endif
#undef RESTRICT_CustomDnieCallbackHandler

#if __has_feature(nullability)
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wnullability"
#pragma GCC diagnostic ignored "-Wnullability-completeness"
#endif

#if !defined (CustomDnieCallbackHandler_) && (INCLUDE_ALL_CustomDnieCallbackHandler || defined(INCLUDE_CustomDnieCallbackHandler))
#define CustomDnieCallbackHandler_

#define RESTRICT_JavaxSecurityAuthCallbackCallbackHandler 1
#define INCLUDE_JavaxSecurityAuthCallbackCallbackHandler 1
#include "javax/security/auth/callback/CallbackHandler.h"

@class IOSCharArray;
@class IOSObjectArray;

@interface CustomDnieCallbackHandler : NSObject < JavaxSecurityAuthCallbackCallbackHandler >

#pragma mark Public

- (instancetype __nonnull)initWithNSString:(NSString *)c
                             withCharArray:(IOSCharArray *)p;

- (instancetype __nonnull)initWithNSString:(NSString *)c
                              withNSString:(NSString *)p;

- (void)handleWithJavaxSecurityAuthCallbackCallbackArray:(IOSObjectArray *)callbacks;

// Disallowed inherited constructors, do not use.

- (instancetype __nonnull)init NS_UNAVAILABLE;

@end

J2OBJC_STATIC_INIT(CustomDnieCallbackHandler)

FOUNDATION_EXPORT void CustomDnieCallbackHandler_initWithNSString_withNSString_(CustomDnieCallbackHandler *self, NSString *c, NSString *p);

FOUNDATION_EXPORT CustomDnieCallbackHandler *new_CustomDnieCallbackHandler_initWithNSString_withNSString_(NSString *c, NSString *p) NS_RETURNS_RETAINED;

FOUNDATION_EXPORT CustomDnieCallbackHandler *create_CustomDnieCallbackHandler_initWithNSString_withNSString_(NSString *c, NSString *p);

FOUNDATION_EXPORT void CustomDnieCallbackHandler_initWithNSString_withCharArray_(CustomDnieCallbackHandler *self, NSString *c, IOSCharArray *p);

FOUNDATION_EXPORT CustomDnieCallbackHandler *new_CustomDnieCallbackHandler_initWithNSString_withCharArray_(NSString *c, IOSCharArray *p) NS_RETURNS_RETAINED;

FOUNDATION_EXPORT CustomDnieCallbackHandler *create_CustomDnieCallbackHandler_initWithNSString_withCharArray_(NSString *c, IOSCharArray *p);

J2OBJC_TYPE_LITERAL_HEADER(CustomDnieCallbackHandler)

#endif


#if __has_feature(nullability)
#pragma clang diagnostic pop
#endif
#pragma pop_macro("INCLUDE_ALL_CustomDnieCallbackHandler")
