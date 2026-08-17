#import "DNIeSwiftBridge.h"

#import "es/gob/jmulticard/card/dnie/DnieFactory.h"

@implementation DNIeSwiftBridge

+ (nullable JavaSecurityCertX509Certificate *)
    certificateFromDnie:(EsGobJmulticardCardDnieDnie *)dnie
                  alias:(NSString *)alias {
  return [dnie getCertificateWithNSString:alias];
}

+ (nullable EsGobJmulticardCardDnieDnie *)
    dnieWithConnection:(id<EsGobJmulticardConnectionApduConnection>)connection
      passwordCallback:(nullable JavaxSecurityAuthCallbackPasswordCallback *)passwordCallback
          cryptoHelper:(EsGobJmulticardCryptoHelper *)cryptoHelper
       callbackHandler:(id<JavaxSecurityAuthCallbackCallbackHandler>)callbackHandler
     includeCloneCards:(BOOL)includeCloneCards {
  return [EsGobJmulticardCardDnieDnieFactory
      getDnieWithEsGobJmulticardConnectionApduConnection:connection
           withJavaxSecurityAuthCallbackPasswordCallback:passwordCallback
                         withEsGobJmulticardCryptoHelper:cryptoHelper
            withJavaxSecurityAuthCallbackCallbackHandler:callbackHandler
                                             withBoolean:includeCloneCards];
}

+ (nullable id<EsGobJmulticardCardPrivateKeyReference>)
    privateKeyFromDnie:(EsGobJmulticardCardDnieDnie *)dnie
                 alias:(NSString *)alias {
  return [dnie getPrivateKeyWithNSString:alias];
}

@end
