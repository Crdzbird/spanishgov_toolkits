#import "DNIeExceptionCatcher.h"

@implementation DNIeExceptionCatcher

+ (BOOL)tryBlock:(void(NS_NOESCAPE ^)(void))tryBlock
           error:(NSError *_Nullable *_Nullable)error {
  @try {
    tryBlock();
    return YES;
  } @catch (NSException *exception) {
    if (error) {
      NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
      if (exception.reason) {
        userInfo[@"reason"] = exception.reason;
        userInfo[NSLocalizedDescriptionKey] = exception.reason;
      }
      if (exception.userInfo) {
        [userInfo addEntriesFromDictionary:exception.userInfo];
      }
      *error = [NSError errorWithDomain:exception.name
                                   code:0
                               userInfo:userInfo];
    }
    return NO;
  }
}

@end
