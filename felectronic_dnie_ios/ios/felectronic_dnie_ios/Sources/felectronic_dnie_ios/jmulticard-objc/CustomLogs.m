//
//  CustomLogs.m
//
//  Created by Arturo Carretero Calvo on 3/1/23.
//  Copyright © 2023. All rights reserved.
//

#import "CustomLogs.h"

@implementation CustomLogs

#pragma mark Public

+ (void)printLog:(NSString *)message {
#if DEBUG
  NSLog(@"%@", message);
#endif
}

@end
