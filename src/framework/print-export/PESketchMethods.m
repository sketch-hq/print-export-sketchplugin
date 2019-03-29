//
//  PESketchMethods.m
//  print-export
//
//  Created by Mark Horgan on 27/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "PESketchMethods.h"
#import "MSConstants.h"
#import "MSImmutableLayerAncestry.h"
#import "MSExportRequest.h"
#import "MSExportManager.h"
#import "MSLayer.h"

@implementation PESketchMethods

+ (NSData*)imageDataOfLayer:(MSImmutableLayer *)layer scale:(double)scale documentData:(MSImmutableDocumentData *)documentData {
    Class cls = NSClassFromString(kMSImmutableLayerAncestry);
    MSImmutableLayerAncestry * layerAncestry = [cls alloc];
    SEL selector = NSSelectorFromString(@"initWithLayer:document:");
    typedef MSImmutableLayerAncestry* (*MethodType1)(MSImmutableLayerAncestry *, SEL, MSImmutableLayer *, MSImmutableDocumentData *);
    MethodType1 method1 = (MethodType1)[layerAncestry methodForSelector:selector];
    layerAncestry = method1(layerAncestry, selector, layer, documentData);
    
    selector = NSSelectorFromString(@"formatWithScale:name:fileFormat:");
    typedef id (*MethodType2)(Class, SEL, double, NSString *, NSString *);
    cls = NSClassFromString(kMSExportFormat);
    MethodType2 method2 = (MethodType2)[cls methodForSelector:selector];
    id exportFormat = method2(cls, selector, scale, @"", @"png");
    
    selector = NSSelectorFromString(@"exportRequestsFromLayerAncestry:exportFormats:");
    typedef NSArray * (*MethodType3)(Class, SEL, MSImmutableLayerAncestry *, NSArray *);
    cls = NSClassFromString(kMSExportRequest);
    MethodType3 method3 = (MethodType3)[cls methodForSelector:selector];
    NSArray *exportRequests = method3(cls, selector, layerAncestry, @[exportFormat]);
    MSExportRequest *exportRequest = exportRequests.firstObject;
    [exportRequest setValue:[NSNumber numberWithBool:YES] forKey:@"includeArtboardBackground"];
    
    cls = NSClassFromString(kMSExportManager);
    MSExportManager *exportManager = [cls alloc];
    selector = NSSelectorFromString(@"init");
    typedef MSExportManager* (*MethodType4)(MSExportManager *, SEL);
    MethodType4 method4 = (MethodType4)[exportManager methodForSelector:selector];
    exportManager = method4(exportManager, selector);
    
    selector = NSSelectorFromString(@"exportedDataForRequest:");
    typedef NSData * (*MethodType5)(MSExportManager *, SEL, MSExportRequest *);
    MethodType5 method5 = (MethodType5)[exportManager methodForSelector:selector];
    return method5(exportManager, selector, exportRequest);
}

+ (MSImmutableLayer*)immutableLayerWithID:(NSString *)layerID documentData:(MSDocumentData *)documentData {
    if (layerID == nil) {
        return nil;
    }
    SEL selector = NSSelectorFromString(@"layerWithID:");
    typedef MSLayer * (*MethodType)(MSDocumentData *, SEL, NSString *);
    MethodType method = (MethodType)[documentData methodForSelector:selector];
    return ((MSLayer*)method(documentData, selector, layerID)).immutableModelObject;
}

+ (void)displayFlashMessage:(NSString *)message document:(MSDocument *)document {
    if ([document respondsToSelector:NSSelectorFromString(@"currentContentViewController")]) {
        // >= 47
        MSFlashController *flashController = document.currentContentViewController.flashController;
        SEL selector = NSSelectorFromString(@"displayFlashMessage:");
        typedef id (*MethodType)(MSFlashController *, SEL, NSString*);
        MethodType method = (MethodType)[flashController methodForSelector:selector];
        method(flashController, selector, message);
    } else {
        // < 47
        SEL selector = NSSelectorFromString(@"displayMessage:");
        typedef void (*MethodType)(MSDocument*, SEL, NSString*);
        MethodType method = (MethodType)[document methodForSelector:selector];
        method(document, selector, message);
    }
}

+ (MSImmutableLayerGroup *)detachedLayerGroupRecursively:(BOOL)recursively withDocument:(MSImmutableDocumentData *)documentData symbolInstance:(MSImmutableSymbolInstance *)symbolInstance {
    SEL selector = NSSelectorFromString(@"detachedLayerGroupRecursively:withDocument:visitedSymbols:");
    typedef id (*MethodType)(MSImmutableSymbolInstance *, SEL, BOOL, MSImmutableDocumentData *, id);
    MethodType method = (MethodType)[symbolInstance methodForSelector:selector];
    return method(symbolInstance, selector, recursively, documentData, nil);
}

@end
