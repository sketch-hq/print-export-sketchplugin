//
//  PEFlowConnection.h
//  print-export
//
//  Created by Mark Horgan on 25/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "types.h"

@interface PEFlowConnection : NSObject

@property (readonly, nonatomic) PEFlowConnectionType type;
// relative to the source artboard
@property (readonly, nonatomic) CGRect frame;
@property (readonly, nonatomic) NSString *destinationArtboardID;
@property (readonly, nonatomic) BOOL isBackAction;

- (instancetype)initWithType:(PEFlowConnectionType)type frame:(CGRect)frame destinationArtboardID:(NSString*)destinationArtboardID;

@end
