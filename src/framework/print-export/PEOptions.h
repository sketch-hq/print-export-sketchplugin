//
//  PEOptions.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "types.h"

@interface PEOptions : NSObject

@property (readonly, nonatomic) PEExportType exportType;
@property (readonly, nonatomic) PEScope scope;
@property (readonly, nonatomic) CGSize pageSize;
@property (readonly, nonatomic) BOOL includeCropMarks;
@property (readonly, nonatomic) CGFloat bleed;
@property (readonly, nonatomic) CGFloat slug;
@property (readonly, nonatomic) BOOL hasCropMarks;

- (instancetype)initWithOptions:(NSDictionary *)options;

@end
