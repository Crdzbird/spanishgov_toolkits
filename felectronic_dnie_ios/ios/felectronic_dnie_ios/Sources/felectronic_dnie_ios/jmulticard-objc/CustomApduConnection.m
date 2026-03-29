//
//  CustomApduConnection.m
//
//  Created by Arturo Carretero Calvo on 3/1/23.
//  Copyright © 2023. All rights reserved.
//

#import <CoreNFC/CoreNFC.h>

#import "CustomApduConnection.h"
#import "CustomLogs.h"

#include "IOSClass.h"
#include "IOSObjectArray.h"
#include "IOSPrimitiveArray.h"
#include "J2ObjC_source.h"
#include "es/gob/jmulticard/HexUtils.h"
#include "es/gob/jmulticard/apdu/CommandApdu.h"
#include "es/gob/jmulticard/apdu/ResponseApdu.h"
#include "es/gob/jmulticard/apdu/StatusWord.h"
#include "es/gob/jmulticard/connection/AbstractApduConnectionIso7816.h"
#include "es/gob/jmulticard/apdu/iso7816four/GetResponseApduCommand.h"
#include "java/lang/IllegalArgumentException.h"
#include "java/lang/System.h"
#include "java/util/Arrays.h"
#include "Byte.h"
#include "es/gob/jmulticard/connection/ApduConnection.h"
#include "es/gob/jmulticard/connection/ApduConnectionProtocol.h"

#if __has_feature(objc_arc)
#error "es/gob/jmulticard/apdu/connection/CustomApduConnection must not be compiled with ARC (-fobjc-arc)"
#endif

inline jbyte EsGobJmulticardConnectionAbstractApduConnectionIso7816_get_TAG_RESPONSE_PENDING(void);
#define EsGobJmulticardApduConnectionAbstractApduConnectionIso7816_TAG_RESPONSE_PENDING 97
J2OBJC_STATIC_FIELD_CONSTANT(EsGobJmulticardApduConnectionAbstractApduConnectionIso7816, TAG_RESPONSE_PENDING, jbyte)

inline jbyte EsGobJmulticardConnectionAbstractApduConnectionIso7816_get_TAG_RESPONSE_INVALID_LENGTH(void);
#define EsGobJmulticardApduConnectionAbstractApduConnectionIso7816_TAG_RESPONSE_INVALID_LENGTH 108
J2OBJC_STATIC_FIELD_CONSTANT(EsGobJmulticardApduConnectionAbstractApduConnectionIso7816, TAG_RESPONSE_INVALID_LENGTH, jbyte)

@interface CustomApduConnection () {
@public
  id nfcTagReaderSession_;
  id nfcTagObject_;
}

@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic) dispatch_time_t time;

@end

J2OBJC_FIELD_SETTER(CustomApduConnection, nfcTagReaderSession_, id)
J2OBJC_FIELD_SETTER(CustomApduConnection, nfcTagObject_, id)

@implementation CustomApduConnection

- (instancetype)init {
  CustomApduConnection_initWithId_withId_(self, nil, nil);
  return self;
}

- (instancetype)initWithId:(id)nfcTagRdrSess withId:(id)nfcTag {
  CustomApduConnection_initWithId_withId_(self, nfcTagRdrSess, nfcTag);
  return self;
}

- (void)close {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"session.invalidate" object: nil userInfo: nil];
}

- (IOSByteArray *)reset {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"session.begin" object: nil userInfo: nil];

  IOSByteArray *atr = [IOSByteArray arrayWithBytes: (jbyte[]) {
    (jbyte) (jint) 0x3B,
    (jbyte) (jint) 0x88,
    (jbyte) (jint) 0x80,
    (jbyte) (jint) 0x01,
    (jbyte) (jint) 0xE1,
    (jbyte) (jint) 0xF3,
    (jbyte) (jint) 0x5E,
    (jbyte) (jint) 0x11,
    (jbyte) (jint) 0x77,
    (jbyte) (jint) 0x81,
    (jbyte) (jint) 0xA1,
    (jbyte) (jint) 0x00,
    (jbyte) (jint) 0x03 } count:13];

  return atr;
}

- (jboolean)isOpen {
  return YES;
}

- (EsGobJmulticardApduResponseApdu *)transmitWithEsGobJmulticardApduCommandApdu:(EsGobJmulticardApduCommandApdu *)command {
  self.apduResponse = nil;

  if (command == nil) {
    [CustomLogs printLog: @"transmitWithEsGobJmulticardApduCommandApdu: error: the apdu command null isn't permitted."];
    return nil;
  } else if (((IOSByteArray *) nil_chk([command getBytes]))->size_ > [self getMaxApduSize]) {
    [CustomLogs printLog: @"transmitWithEsGobJmulticardApduCommandApdu: error: the apdu command exceeds the maximum size."];
    return nil;
  }

  EsGobJmulticardApduResponseApdu *response = [self internalTransmitWithByteArray: [command getBytes]];

  if ([((EsGobJmulticardApduStatusWord *) nil_chk([((EsGobJmulticardApduResponseApdu *) nil_chk(response)) getStatusWord])) getMsb] == EsGobJmulticardApduConnectionAbstractApduConnectionIso7816_TAG_RESPONSE_PENDING) {
    [CustomLogs printLog: @"transmitWithEsGobJmulticardApduCommandApdu: error:: EsGobJmulticardConnectionAbstractApduConnectionIso7816_TAG_RESPONSE_PENDING"];
    return nil;
  } else if ([((EsGobJmulticardApduStatusWord *) nil_chk([response getStatusWord])) getMsb] == EsGobJmulticardApduConnectionAbstractApduConnectionIso7816_TAG_RESPONSE_INVALID_LENGTH && [command getCla] == (jbyte) (jint) 0x00) {
    [CustomLogs printLog: @"transmitWithEsGobJmulticardApduCommandApdu: error:: EsGobJmulticardConnectionAbstractApduConnectionIso7816_TAG_RESPONSE_INVALID_LENGTH"];
    return nil;
  }

  return response;
}

- (EsGobJmulticardApduResponseApdu *)internalTransmitWithByteArray:(IOSByteArray *)apdu {
  self.apduResponse = nil;
  self.semaphore = dispatch_semaphore_create(0);
  self.time = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    EsGobJmulticardApduCommandApdu *command = [[EsGobJmulticardApduCommandApdu alloc] initWithByteArray: apdu];
    NSData *data = [[command getData] toNSData];
    NFCISO7816APDU *apdu = [[NFCISO7816APDU alloc] initWithInstructionClass: [command getCla]
                                                            instructionCode: [command getIns]
                                                                p1Parameter: [command getP1]
                                                                p2Parameter: [command getP2]
                                                                       data: data
                                                     expectedResponseLength: data.length];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject: apdu forKey: @"apdu"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"apdu.command" object: nil userInfo: userInfo];
  });

  dispatch_semaphore_wait(self.semaphore, self.time);

  return self.apduResponse;
}

- (void)setTagSendCommandResponse:(NSData *)data {
  IOSByteArray *responseByteArray = [IOSByteArray arrayWithNSData: data];
  self.apduResponse = [[EsGobJmulticardApduResponseApdu alloc] initWithByteArray: responseByteArray];

  dispatch_semaphore_signal(self.semaphore);
}

#pragma mark These methods are out of use

- (NSString *)getTerminalInfoWithInt:(jint)terminal {
  return @"iOS NFC";
}

- (jint)getMaxApduSize {
  return (jint) 0xff;
}

- (IOSLongArray *)getTerminalsWithBoolean:(jboolean)onlyWithCardPresent {
  return [IOSLongArray arrayWithLongs:(jlong[]){ 0LL } count:1];
}

- (id<EsGobJmulticardConnectionApduConnection>)getSubConnection {
  return self.getSubConnection;
}

- (void)open {
}

- (void)setProtocolWithEsGobJmulticardConnectionApduConnectionProtocol:(EsGobJmulticardConnectionApduConnectionProtocol *)p {
}

- (void)addCardConnectionListenerWithEsGobJmulticardConnectionCardConnectionListener:(id<EsGobJmulticardConnectionCardConnectionListener>)ccl {
}

- (void)removeCardConnectionListenerWithEsGobJmulticardConnectionCardConnectionListener:(id<EsGobJmulticardConnectionCardConnectionListener>)ccl {
}

- (void)setTerminalWithInt:(jint)t {
}

- (void)dealloc {
  RELEASE_(nfcTagReaderSession_);
  RELEASE_(nfcTagObject_);
  [super dealloc];
}

+ (const J2ObjcClassInfo *)__metadata {
  static J2ObjcMethodInfo methods[] = {
    { NULL, NULL, 0x1, -1, 0, -1, -1, -1, -1 },
    { NULL, "V", 0x1, -1, -1, 1, -1, -1, -1 },
    { NULL, "[B", 0x1, -1, -1, 1, -1, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LEsGobJmulticardApduResponseApdu;", 0x4, 2, 3, 1, -1, -1, -1 },
    { NULL, "LNSString;", 0x1, 4, 5, 1, -1, -1, -1 },
    { NULL, "I", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "[J", 0x1, 6, 7, 1, -1, -1, -1 },
    { NULL, "LEsGobJmulticardApduConnectionApduConnection;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "V", 0x1, -1, -1, 1, -1, -1, -1 },
    { NULL, "V", 0x1, 8, 9, -1, -1, -1, -1 },
    { NULL, "V", 0x1, 10, 11, -1, -1, -1, -1 },
    { NULL, "V", 0x1, 12, 11, -1, -1, -1, -1 },
    { NULL, "V", 0x1, 13, 5, 1, -1, -1, -1 },
  };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-multiple-method-names"
#pragma clang diagnostic ignored "-Wundeclared-selector"
  methods[0].selector = @selector(initWithId:withId:);
  methods[1].selector = @selector(close);
  methods[2].selector = @selector(reset);
  methods[3].selector = @selector(isOpen);
  methods[4].selector = @selector(internalTransmitWithByteArray:);
  methods[5].selector = @selector(getTerminalInfoWithInt:);
  methods[6].selector = @selector(getMaxApduSize);
  methods[7].selector = @selector(getTerminalsWithBoolean:);
  methods[8].selector = @selector(getSubConnection);
  methods[9].selector = @selector(open);
  methods[10].selector = @selector(setProtocolWithEsGobJmulticardApduConnectionApduConnectionProtocol:);
  methods[11].selector = @selector(addCardConnectionListenerWithEsGobJmulticardApduConnectionCardConnectionListener:);
  methods[12].selector = @selector(removeCardConnectionListenerWithEsGobJmulticardApduConnectionCardConnectionListener:);
  methods[13].selector = @selector(setTerminalWithInt:);
#pragma clang diagnostic pop
  static const J2ObjcFieldInfo fields[] = {
    { "nfcTagReaderSession_", "LNSObject;", .constantValue.asLong = 0, 0x12, -1, -1, -1, -1 },
    { "nfcTagObject_", "LNSObject;", .constantValue.asLong = 0, 0x12, -1, -1, -1, -1 },
  };
  static const void *ptrTable[] = { "LNSObject;LNSObject;", "LEsGobJmulticardApduConnectionApduConnectionException;", "internalTransmit", "[B", "getTerminalInfo", "I", "getTerminals", "Z", "setProtocol", "LEsGobJmulticardApduConnectionApduConnectionProtocol;", "addCardConnectionListener", "LEsGobJmulticardApduConnectionCardConnectionListener;", "removeCardConnectionListener", "setTerminal" };
  static const J2ObjcClassInfo _CustomApduConnection = { "CustomApduConnection", "es.gob.jmulticard.apdu.connection", ptrTable, methods, fields, 7, 0x1, 14, 2, -1, -1, -1, -1, -1 };
  return &_CustomApduConnection;
}

@end

void CustomApduConnection_initWithId_withId_(CustomApduConnection *self, id nfcTagRdrSess, id nfcTag) {
  EsGobJmulticardConnectionAbstractApduConnectionIso7816_init(self);
  JreStrongAssign(&self->nfcTagReaderSession_, nfcTagRdrSess);
  JreStrongAssign(&self->nfcTagObject_, nfcTag);
}

CustomApduConnection *new_CustomApduConnection_initWithId_withId_(id nfcTagRdrSess, id nfcTag) {
  J2OBJC_NEW_IMPL(CustomApduConnection, initWithId_withId_, nfcTagRdrSess, nfcTag)
}

CustomApduConnection *create_CustomApduConnection_initWithId_withId_(id nfcTagRdrSess, id nfcTag) {
  J2OBJC_CREATE_IMPL(CustomApduConnection, initWithId_withId_, nfcTagRdrSess, nfcTag)
}

J2OBJC_CLASS_TYPE_LITERAL_SOURCE(CustomApduConnection)
