//
//  MSImmutableFlowConnection.h
//  print-export
//
//  Created by Mark Horgan on 25/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "MSImmutableModelObject.h"

@interface MSImmutableFlowConnection: MSImmutableModelObject

@property (readonly, nonatomic) BOOL isBackAction;
@property (readonly, nonatomic) NSString *destinationArtboardID;

@end
