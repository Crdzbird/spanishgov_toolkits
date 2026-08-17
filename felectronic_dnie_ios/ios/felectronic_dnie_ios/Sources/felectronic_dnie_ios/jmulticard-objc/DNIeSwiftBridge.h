#import <Foundation/Foundation.h>

// Complete definitions, not forward declarations: Swift drops any method whose
// parameter or return types it cannot fully model.
#import "es/gob/jmulticard/CryptoHelper.h"
#import "es/gob/jmulticard/card/dnie/Dnie.h"
#import "es/gob/jmulticard/card/PrivateKeyReference.h"
#import "es/gob/jmulticard/connection/ApduConnection.h"
#import "java/security/cert/X509Certificate.h"
#import "javax/security/auth/callback/CallbackHandler.h"
#import "javax/security/auth/callback/PasswordCallback.h"

NS_ASSUME_NONNULL_BEGIN

/// Objective-C access to the two jmulticard entry points Swift cannot import.
///
/// `-[Dnie getCertificateWithNSString:]` and
/// `+[DnieFactory getDnieWith...:withBoolean:]` are declared normally and are
/// callable from Objective-C, but Swift's importer does not expose them: it
/// reports "has no member". Everything obvious was ruled out — the types
/// import in isolation, the superclass chain is complete up to NSObject,
/// inheritance works (`getCardName` imports, renamed to `getName`), the
/// declarations sit inside the `@interface`, preprocessing shows no
/// availability or visibility attributes, and the umbrella imports the return
/// types before the declaring headers. The cause is still unexplained.
///
/// This class re-exposes both through signatures Swift does import. Note that
/// the *types* are not the problem, so these wrappers stay fully typed — no
/// `id`, no loss of compile-time checking at the call sites.
///
/// `NS_SWIFT_NAME` pins the Swift spelling rather than relying on the
/// importer's "omit needless words" transformation, which is what produced
/// the surprising `getDnieNfc(with:with:with:)` elsewhere in this package.
@interface DNIeSwiftBridge : NSObject

/// Wraps `-[EsGobJmulticardCardDnieDnie getCertificateWithNSString:]`.
///
/// Accepts any `Dnie` subclass, including `DnieNfc`.
+ (nullable JavaSecurityCertX509Certificate *)
    certificateFromDnie:(EsGobJmulticardCardDnieDnie *)dnie
                  alias:(NSString *)alias
    NS_SWIFT_NAME(certificate(fromDnie:alias:));

/// Wraps `-[EsGobJmulticardCardDnieDnie getPrivateKeyWithNSString:]`.
///
/// Dropped by Swift's importer for the same unexplained reason as
/// `getCertificateWithNSString:`.
+ (nullable id<EsGobJmulticardCardPrivateKeyReference>)
    privateKeyFromDnie:(EsGobJmulticardCardDnieDnie *)dnie
                 alias:(NSString *)alias
    NS_SWIFT_NAME(privateKey(fromDnie:alias:));

/// Wraps the five-argument
/// `+[EsGobJmulticardCardDnieDnieFactory getDnieWith...:withBoolean:]`.
+ (nullable EsGobJmulticardCardDnieDnie *)
    dnieWithConnection:(id<EsGobJmulticardConnectionApduConnection>)connection
      passwordCallback:(nullable JavaxSecurityAuthCallbackPasswordCallback *)passwordCallback
          cryptoHelper:(EsGobJmulticardCryptoHelper *)cryptoHelper
       callbackHandler:(id<JavaxSecurityAuthCallbackCallbackHandler>)callbackHandler
     includeCloneCards:(BOOL)includeCloneCards
    NS_SWIFT_NAME(dnie(connection:passwordCallback:cryptoHelper:callbackHandler:includeCloneCards:));

@end

NS_ASSUME_NONNULL_END
