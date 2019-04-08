//
//  PEFlowConnection.m
//  print-export
//
//  Created by Mark Horgan on 25/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "PEFlowConnection.h"

@implementation PEFlowConnection

- (instancetype)initWithType:(PEFlowConnectionType)type frame:(CGRect)frame destinationArtboardID:(NSString *)destinationArtboardID {
    if (self = [super init]) {
        _type = type;
        _frame = frame;
        _destinationArtboardID = destinationArtboardID;
        _isBackAction = destinationArtboardID == nil;
    }
    return self;
}

@end
