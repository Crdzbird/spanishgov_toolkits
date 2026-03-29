//
//  CustomApduConnection.h
//
//  Created by Arturo Carretero Calvo on 3/1/23.
//  Copyright © 2023. All rights reserved.
//

#include "J2ObjC_header.h"

#pragma push_macro("INCLUDE_ALL_CustomApduConnection")
#ifdef RESTRICT_CustomApduConnection
#define INCLUDE_ALL_CustomApduConnection 0
#else
#define INCLUDE_ALL_CustomApduConnection 1
#endif
#undef RESTRICT_CustomApduConnection

#if __has_feature(nullability)
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wnullability"
#pragma GCC diagnostic ignored "-Wnullability-completeness"
#endif

#if !defined (CustomApduConnection_) && (INCLUDE_ALL_CustomApduConnection || defined(INCLUDE_CustomApduConnection))
#define CustomApduConnection_

#define RESTRICT_EsGobJmulticardApduConnectionAbstractApduConnectionIso7816 1
#define INCLUDE_EsGobJmulticardApduConnectionAbstractApduConnectionIso7816 1
#include "es/gob/jmulticard/connection/AbstractApduConnectionIso7816.h"

@class EsGobJmulticardConnectionApduConnectionProtocol;
@class EsGobJmulticardApduResponseApdu;
@class IOSByteArray;
@class IOSLongArray;
@protocol EsGobJmulticardConnectionApduConnection;
@protocol EsGobJmulticardConnectionCardConnectionListener;

@interface CustomApduConnection : EsGobJmulticardConnectionAbstractApduConnectionIso7816

#pragma mark Public

- (instancetype __nonnull)init;

- (instancetype __nonnull)initWithId:(id)nfcTagRdrSess withId:(id)nfcTag;

- (void)addCardConnectionListenerWithEsGobJmulticardConnectionCardConnectionListener:(id<EsGobJmulticardConnectionCardConnectionListener>)ccl;

- (void)close;

- (jint)getMaxApduSize;

- (id<EsGobJmulticardConnectionApduConnection>)getSubConnection;

- (NSString *)getTerminalInfoWithInt:(jint)terminal;

- (IOSLongArray *)getTerminalsWithBoolean:(jboolean)onlyWithCardPresent;

- (jboolean)isOpen;

- (void)open;

- (void)removeCardConnectionListenerWithEsGobJmulticardConnectionCardConnectionListener:(id<EsGobJmulticardConnectionCardConnectionListener>)ccl;

- (IOSByteArray *)reset;

- (void)setProtocolWithEsGobJmulticardConnectionApduConnectionProtocol:(EsGobJmulticardConnectionApduConnectionProtocol *)p;

- (void)setTerminalWithInt:(jint)t;

#pragma mark Protected

- (EsGobJmulticardApduResponseApdu *)internalTransmitWithByteArray:(IOSByteArray *)apdu;

#pragma mark Custom public

- (void)setTagSendCommandResponse:(NSData *)data;

#pragma mark Properties

@property (nonatomic, strong) EsGobJmulticardApduResponseApdu *apduResponse;

@end

J2OBJC_EMPTY_STATIC_INIT(CustomApduConnection)

FOUNDATION_EXPORT void CustomApduConnection_initWithId_withId_(CustomApduConnection *self, id nfcTagRdrSess, id nfcTag);

FOUNDATION_EXPORT CustomApduConnection *new_CustomApduConnection_initWithId_withId_(id nfcTagRdrSess, id nfcTag) NS_RETURNS_RETAINED;

FOUNDATION_EXPORT CustomApduConnection *create_CustomApduConnection_initWithId_withId_(id nfcTagRdrSess, id nfcTag);

J2OBJC_TYPE_LITERAL_HEADER(CustomApduConnection)

#endif

#if __has_feature(nullability)
#pragma clang diagnostic pop
#endif
#pragma pop_macro("INCLUDE_ALL_CustomApduConnection")
