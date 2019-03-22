//
//  PEUtils.m
//  print-export
//
//  Created by Mark Horgan on 21/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "PEUtils.h"
#import "MSConstants.h"
#import "MSImmutableLayerAncestry.h"
#import "MSExportRequest.h"
#import "MSLayer.h"
#import "MSExportManager.h"

CGFloat PEMMToUnit(CGFloat millimeter) {
    return (millimeter / 25.4) * 72;
}

CGRect PEMMRectToUnitRect(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
    return CGRectMake(PEMMToUnit(x), PEMMToUnit(y), PEMMToUnit(width), PEMMToUnit(height));
}

@implementation PEUtils

+ (CGPDFDocumentRef)PDFOfArtboard:(MSArtboardGroup*)artboard {
    SEL selector = NSSelectorFromString(@"ancestryWithMSLayer:");
    typedef MSImmutableLayerAncestry* (*MethodType1)(Class, SEL, MSLayer*);
    Class cls = NSClassFromString(kMSImmutableLayerAncestry);
    MethodType1 method1 = (MethodType1)[cls methodForSelector:selector];
    MSImmutableLayerAncestry* layerAncestry = method1(cls, selector, artboard);
    
    selector = NSSelectorFromString(@"formatWithScale:name:fileFormat:");
    typedef id (*MethodType2)(Class, SEL, double, NSString*, NSString*);
    cls = NSClassFromString(kMSExportFormat);
    MethodType2 method2 = (MethodType2)[cls methodForSelector:selector];
    id exportFormat = method2(cls, selector, 1, @"", @"pdf");
    
    selector = NSSelectorFromString(@"exportRequestsFromLayerAncestry:exportFormats:");
    typedef NSArray* (*MethodType3)(Class, SEL, MSImmutableLayerAncestry*, NSArray*);
    cls = NSClassFromString(kMSExportRequest);
    MethodType3 method3 = (MethodType3)[cls methodForSelector:selector];
    NSArray *exportRequests = method3(cls, selector, layerAncestry, @[exportFormat]);
    MSExportRequest *exportRequest = exportRequests.firstObject;
    [exportRequest setValue:[NSNumber numberWithBool:YES] forKey:@"includeArtboardBackground"];
    
    cls = NSClassFromString(kMSExportManager);
    MSExportManager *exportManager = [cls alloc];
    selector = NSSelectorFromString(@"init");
    typedef MSExportManager* (*MethodType4)(MSExportManager*, SEL);
    MethodType4 method4 = (MethodType4)[exportManager methodForSelector:selector];
    exportManager = method4(exportManager, selector);
    
    selector = NSSelectorFromString(@"exportedDataForRequest:");
    typedef NSData* (*MethodType5)(MSExportManager*, SEL, MSExportRequest*);
    MethodType5 method5 = (MethodType5)[exportManager methodForSelector:selector];
    NSData *data = method5(exportManager, selector, exportRequest);
    
    return CGPDFDocumentCreateWithProvider(CGDataProviderCreateWithCFData(CFDataCreate(NULL, data.bytes, data.length)));
}

+ (CGSize)fitSize:(CGSize)sourceSize inSize:(CGSize)targetSize {
    CGFloat sourceApsectRatio = sourceSize.width / sourceSize.height;
    CGFloat targetAspectRatio = targetSize.width / targetSize.height;
    CGFloat width = 0, height = 0;
    if (sourceApsectRatio > targetAspectRatio) {
        width = targetSize.width;
        height = sourceSize.height * (targetSize.width / sourceSize.width);
    } else {
        height = targetSize.height;
        width = sourceSize.width * (targetSize.height / sourceSize.height);
    }
    return CGSizeMake(width, height);
}

+ (BOOL)colorIsWhite:(id<MSColor>)color {
    return color.red == 1 && color.green == 1 && color.blue == 1;
}

@end
