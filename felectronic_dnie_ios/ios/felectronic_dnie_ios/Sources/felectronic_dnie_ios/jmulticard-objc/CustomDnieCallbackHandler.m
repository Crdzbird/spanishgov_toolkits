//
//  CustomDnieCallbackHandler.m
//
//  Created by Arturo Carretero Calvo on 3/1/23.
//  Copyright © 2023. All rights reserved.
//

#include "IOSObjectArray.h"
#include "IOSPrimitiveArray.h"
#include "J2ObjC_source.h"
#include "es/gob/jmulticard/callback/CustomTextInputCallback.h"
#include "java/util/logging/Logger.h"
#include "javax/security/auth/callback/Callback.h"
#include "javax/security/auth/callback/PasswordCallback.h"
#include "javax/security/auth/callback/UnsupportedCallbackException.h"
#include "CustomDnieCallbackHandler.h"

#if __has_feature(objc_arc)
#error "test/es/gob/jmulticard/CustomDnieCallbackHandler must not be compiled with ARC (-fobjc-arc)"
#endif

@interface CustomDnieCallbackHandler () {
@public
  NSString *can_;
  IOSCharArray *pin_;
}

@end

J2OBJC_FIELD_SETTER(CustomDnieCallbackHandler, can_, NSString *)
J2OBJC_FIELD_SETTER(CustomDnieCallbackHandler, pin_, IOSCharArray *)

inline JavaUtilLoggingLogger *CustomDnieCallbackHandler_get_LOGGER(void);
static JavaUtilLoggingLogger *CustomDnieCallbackHandler_LOGGER;
J2OBJC_STATIC_FIELD_OBJ_FINAL(CustomDnieCallbackHandler, LOGGER, JavaUtilLoggingLogger *)

J2OBJC_INITIALIZED_DEFN(CustomDnieCallbackHandler)

@implementation CustomDnieCallbackHandler

- (instancetype)initWithNSString:(NSString *)c
                    withNSString:(NSString *)p {
  CustomDnieCallbackHandler_initWithNSString_withNSString_(self, c, p);
  return self;
}

- (instancetype)initWithNSString:(NSString *)c
                   withCharArray:(IOSCharArray *)p {
  CustomDnieCallbackHandler_initWithNSString_withCharArray_(self, c, p);
  return self;
}

- (void)handleWithJavaxSecurityAuthCallbackCallbackArray:(IOSObjectArray *)callbacks {
  if (callbacks != nil) {
    {
      IOSObjectArray *a__ = callbacks;
      id<JavaxSecurityAuthCallbackCallback> const *b__ = a__->buffer_;
      id<JavaxSecurityAuthCallbackCallback> const *e__ = b__ + a__->size_;
      while (b__ < e__) {
        id<JavaxSecurityAuthCallbackCallback> cb = RETAIN_AND_AUTORELEASE(*b__++);
        if (cb != nil) {
          if ([cb isKindOfClass:[EsGobJmulticardCallbackCustomTextInputCallback class]]) {
            [((EsGobJmulticardCallbackCustomTextInputCallback *) cb) setTextWithNSString:can_];
          }
          else if ([cb isKindOfClass:[JavaxSecurityAuthCallbackPasswordCallback class]]) {
            [((JavaxSecurityAuthCallbackPasswordCallback *) cb) setPasswordWithCharArray:pin_];
          }
          else {
            @throw create_JavaxSecurityAuthCallbackUnsupportedCallbackException_initWithJavaxSecurityAuthCallbackCallback_(cb);
          }
        }
      }
    }
  }
  else {
    [((JavaUtilLoggingLogger *) nil_chk(CustomDnieCallbackHandler_LOGGER)) warningWithNSString:@"Se ha recibido un array de Callbacks nulo"];
  }
}

- (void)dealloc {
  RELEASE_(can_);
  RELEASE_(pin_);
  [super dealloc];
}

+ (const J2ObjcClassInfo *)__metadata {
  static J2ObjcMethodInfo methods[] = {
    { NULL, NULL, 0x1, -1, 0, -1, -1, -1, -1 },
    { NULL, NULL, 0x1, -1, 1, -1, -1, -1, -1 },
    { NULL, "V", 0x1, 2, 3, 4, -1, -1, -1 },
  };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-multiple-method-names"
#pragma clang diagnostic ignored "-Wundeclared-selector"
  methods[0].selector = @selector(initWithNSString:withNSString:);
  methods[1].selector = @selector(initWithNSString:withCharArray:);
  methods[2].selector = @selector(handleWithJavaxSecurityAuthCallbackCallbackArray:);
#pragma clang diagnostic pop
  static const J2ObjcFieldInfo fields[] = {
    { "can_", "LNSString;", .constantValue.asLong = 0, 0x12, -1, -1, -1, -1 },
    { "pin_", "[C", .constantValue.asLong = 0, 0x12, -1, -1, -1, -1 },
    { "LOGGER", "LJavaUtilLoggingLogger;", .constantValue.asLong = 0, 0x1a, -1, 5, -1, -1 },
  };
  static const void *ptrTable[] = { "LNSString;LNSString;", "LNSString;[C", "handle", "[LJavaxSecurityAuthCallbackCallback;", "LJavaxSecurityAuthCallbackUnsupportedCallbackException;", &CustomDnieCallbackHandler_LOGGER };
  static const J2ObjcClassInfo _CustomDnieCallbackHandler = { "CustomDnieCallbackHandler", "test.es.gob.jmulticard", ptrTable, methods, fields, 7, 0x11, 3, 3, -1, -1, -1, -1, -1 };
  return &_CustomDnieCallbackHandler;
}

+ (void)initialize {
  if (self == [CustomDnieCallbackHandler class]) {
    JreStrongAssign(&CustomDnieCallbackHandler_LOGGER, JavaUtilLoggingLogger_getLoggerWithNSString_(@"es.gob.jmulticard"));
    J2OBJC_SET_INITIALIZED(CustomDnieCallbackHandler)
  }
}

@end

void CustomDnieCallbackHandler_initWithNSString_withNSString_(CustomDnieCallbackHandler *self, NSString *c, NSString *p) {
  NSObject_init(self);
  JreStrongAssign(&self->can_, c);
  JreStrongAssign(&self->pin_, p != nil ? [p java_toCharArray] : nil);
}

CustomDnieCallbackHandler *new_CustomDnieCallbackHandler_initWithNSString_withNSString_(NSString *c, NSString *p) {
  J2OBJC_NEW_IMPL(CustomDnieCallbackHandler, initWithNSString_withNSString_, c, p)
}

CustomDnieCallbackHandler *create_CustomDnieCallbackHandler_initWithNSString_withNSString_(NSString *c, NSString *p) {
  J2OBJC_CREATE_IMPL(CustomDnieCallbackHandler, initWithNSString_withNSString_, c, p)
}

void CustomDnieCallbackHandler_initWithNSString_withCharArray_(CustomDnieCallbackHandler *self, NSString *c, IOSCharArray *p) {
  NSObject_init(self);
  JreStrongAssign(&self->can_, c);
  JreStrongAssign(&self->pin_, p != nil ? [p java_clone] : nil);
}

CustomDnieCallbackHandler *new_CustomDnieCallbackHandler_initWithNSString_withCharArray_(NSString *c, IOSCharArray *p) {
  J2OBJC_NEW_IMPL(CustomDnieCallbackHandler, initWithNSString_withCharArray_, c, p)
}

CustomDnieCallbackHandler *create_CustomDnieCallbackHandler_initWithNSString_withCharArray_(NSString *c, IOSCharArray *p) {
  J2OBJC_CREATE_IMPL(CustomDnieCallbackHandler, initWithNSString_withCharArray_, c, p)
}

J2OBJC_CLASS_TYPE_LITERAL_SOURCE(CustomDnieCallbackHandler)
