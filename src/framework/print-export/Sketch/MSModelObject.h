//
//  MSModelObject.h
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

@interface MSModelObject: NSObject

@property (readonly, nonatomic) id immutableModelObject;
@property (readonly, copy, nonatomic) NSString *objectID;

@end
