//
//  MSImmutableLayer.h
//  ProtoWire
//
//  Created by Mark Horgan on 30/04/2017.
//  Copyright © 2017 Mark Horgan. All rights reserved.
//

#import "MSImmutableModelObject.h"
#import "MSImmutableFlowConnection.h"

@interface MSImmutableLayer : MSImmutableModelObject

@property (readonly, nonatomic) CGRect rect;
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, nonatomic) MSImmutableFlowConnection *flow;

@end
