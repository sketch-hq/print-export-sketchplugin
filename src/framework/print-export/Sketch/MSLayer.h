//
//  MSLayer.h
//  print-export
//
//  Created by Mark Horgan on 25/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "MSModelObject.h"

@interface MSLayer: MSModelObject

@property (readonly, nonatomic) CGRect rect;
@property (readonly, copy, nonatomic) NSString *name;

@end
