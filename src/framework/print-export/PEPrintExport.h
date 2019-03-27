//
//  PEPrintExport.h
//  print-export
//
//  Created by Mark Horgan on 19/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "types.h"
#import "MSDocument.h"
#import "PEOptions.h"

@interface PEPrintExport : NSObject

+ (void)onShutdown:(NSDictionary *)context;
+ (void)generatePDFWithDocument:(MSDocument *)document filePath:(NSString *)filePath options:(NSDictionary *)options context:(NSDictionary *)pluginContext;

@end
