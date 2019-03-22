//
//  PEOptions.m
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "PEOptions.h"
#import "PEUtils.h"

static NSString *const kOptionKeyExportType = @"exportType";
static NSString *const kOptionKeyScope = @"scope";
static NSString *const kOptionKeyShowArtboardBorder = @"showArtboardBorder";
static NSString *const kOptionKeyShowArtboardName = @"showArtboardName";
static NSString *const kOptionKeyShowPrototypingLinks = @"showPrototypingLinks";
static NSString *const kOptionKeyPageWidth = @"pageWidth";
static NSString *const kOptionKeyPageHeight = @"pageHeight";
static NSString *const kOptionKeyIncludeCropMarks = @"includeCropMarks";
static NSString *const kOptionKeyBleed = @"bleed";
static NSString *const kOptionKeySlug = @"slug";

@implementation PEOptions

- (instancetype)initWithOptions:(NSDictionary *)options {
    if (self = [super init]) {
        NSArray<NSString*> *requiredOptionKeys = @[
                                                   kOptionKeyExportType,
                                                   kOptionKeyScope,
                                                   kOptionKeyShowArtboardBorder,
                                                   kOptionKeyShowArtboardName,
                                                   kOptionKeyShowPrototypingLinks,
                                                   kOptionKeyPageWidth,
                                                   kOptionKeyPageHeight,
                                                   kOptionKeyIncludeCropMarks,
                                                   kOptionKeyBleed,
                                                   kOptionKeySlug];
        for (NSString *key in requiredOptionKeys) {
            if (options[key] == nil) {
                [NSException raise:@"Invalid options" format:@"%@ is missing from options", key];
            }
        }
        _exportType = (PEExportType)((NSNumber*)options[kOptionKeyExportType]).unsignedIntegerValue;
        _scope = (PEScope)((NSNumber*)options[kOptionKeyScope]).unsignedIntegerValue;
        _showArboardBorder = ((NSNumber*)options[kOptionKeyShowArtboardBorder]).boolValue;
        _showArboardName = ((NSNumber*)options[kOptionKeyShowArtboardName]).boolValue;
        _showPrototypingLinks = ((NSNumber*)options[kOptionKeyShowPrototypingLinks]).boolValue;
        _pageSize = CGSizeMake(PEMMToUnit(((NSNumber*)options[kOptionKeyPageWidth]).doubleValue), PEMMToUnit(((NSNumber*)options[kOptionKeyPageHeight]).doubleValue));
        _includeCropMarks = ((NSNumber*)options[kOptionKeyIncludeCropMarks]).boolValue;
        _bleed = PEMMToUnit(((NSNumber*)options[kOptionKeyBleed]).doubleValue);
        _slug = PEMMToUnit(((NSNumber*)options[kOptionKeySlug]).doubleValue);
    }
    return self;
}

- (BOOL)hasCropMarks {
    return self.includeCropMarks && self.slug > 0;
}

@end
