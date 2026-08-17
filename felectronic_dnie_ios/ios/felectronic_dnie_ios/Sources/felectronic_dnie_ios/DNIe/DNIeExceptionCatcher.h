#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridges Objective-C NSException handling to Swift.
///
/// J2ObjC-generated code throws NSException (not NSError).
/// Swift cannot catch NSException with do/try/catch.
/// This helper wraps a block in @try/@catch and converts
/// any thrown NSException to an NSError.
@interface DNIeExceptionCatcher : NSObject

/// Executes the given block. If an NSException is thrown,
/// it is caught and converted to an NSError.
///
/// @param tryBlock The block to execute.
/// @param error On output, an NSError whose domain is the
///              exception name and whose userInfo contains the reason.
/// @return YES if the block executed without exception, NO otherwise.
/// @note `NS_SWIFT_NOTHROW` keeps the `BOOL` + `NSError **` shape in Swift.
///       Without it Swift's importer treats the trailing `NSError **` as a
///       Swift error, imports this as `throws`, and discards the `BOOL`
///       return — so the call sites' `let success = ...tryBlock(_:error:)`
///       failed with "extra argument 'error' in call".
+ (BOOL)tryBlock:(void(NS_NOESCAPE ^)(void))tryBlock
           error:(NSError *_Nullable *_Nullable)error NS_SWIFT_NOTHROW;

@end

NS_ASSUME_NONNULL_END
