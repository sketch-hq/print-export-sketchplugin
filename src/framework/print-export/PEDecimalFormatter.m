//
//  NSDecimalFormatter.m
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "PEDecimalFormatter.h"

static NSRegularExpression *regExp;
static const NSUInteger kMinimumFractionDigits = 0;
static const NSUInteger kMaximumFractionDigits = 2;

@implementation PEDecimalFormatter

- (instancetype)init {
    if (self = [super init]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^ {
            NSError *error = nil;
            regExp = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^\\d*(%@\\d{%lu,%lu})?$", [self.decimalSeparator isEqualToString:@"."] ? @"\\." : self.decimalSeparator, kMinimumFractionDigits, kMaximumFractionDigits] options:0 error:&error];
            if (error != nil) {
                NSLog(@"Invalid regular expression: %@", error.localizedDescription);
            }
        });
        self.numberStyle = NSNumberFormatterDecimalStyle;
        self.minimumFractionDigits = kMinimumFractionDigits;
        self.maximumFractionDigits = kMaximumFractionDigits;
        self.allowsFloats = YES;
        self.hasThousandSeparators = NO;
    }
    return self;
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error {
    if (partialString.length == 0) {
        return YES;
    }
    
    NSTextCheckingResult *result = [regExp firstMatchInString:partialString options:0 range:NSMakeRange(0, partialString.length)];
    NSString *otherDecimalSeperator = [self.decimalSeparator isEqualToString:@"."] ? @"," : @".";
    *newString = [partialString stringByReplacingOccurrencesOfString:otherDecimalSeperator withString:self.decimalSeparator];
    return result.range.location == 0 && result.range.length == partialString.length;
}

@end
