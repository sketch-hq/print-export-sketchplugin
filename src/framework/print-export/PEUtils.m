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
#import "MSExportManager.h"
#import "MSImmutableLayer.h"
#import "MSLayer.h"

CGFloat PEMMToUnit(CGFloat millimeter) {
    return (millimeter / 25.4) * 72;
}

CGRect PEMMRectToUnitRect(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
    return CGRectMake(PEMMToUnit(x), PEMMToUnit(y), PEMMToUnit(width), PEMMToUnit(height));
}

@implementation PEUtils

+ (CGPDFDocumentRef)createPDFPageOfArtboard:(MSImmutableArtboardGroup *)artboard documentData:(MSImmutableDocumentData *)documentData {
    Class cls = NSClassFromString(kMSImmutableLayerAncestry);
    MSImmutableLayerAncestry * layerAncestry = [cls alloc];
    SEL selector = NSSelectorFromString(@"initWithLayer:document:");
    typedef MSImmutableLayerAncestry* (*MethodType1)(MSImmutableLayerAncestry *, SEL, MSImmutableLayer *, MSImmutableDocumentData *);
    MethodType1 method1 = (MethodType1)[layerAncestry methodForSelector:selector];
    layerAncestry = method1(layerAncestry, selector, artboard, documentData);
    
    selector = NSSelectorFromString(@"formatWithScale:name:fileFormat:");
    typedef id (*MethodType2)(Class, SEL, double, NSString *, NSString *);
    cls = NSClassFromString(kMSExportFormat);
    MethodType2 method2 = (MethodType2)[cls methodForSelector:selector];
    id exportFormat = method2(cls, selector, 1, @"", @"pdf");
    
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
    NSData *data = method5(exportManager, selector, exportRequest);
    
    CFDataRef cfData = CFDataCreate(kCFAllocatorDefault, data.bytes, data.length);
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(cfData);
    CFRelease(cfData);
    CGPDFDocumentRef PDF = CGPDFDocumentCreateWithProvider(dataProvider);
    CFRelease(dataProvider);
    return PDF;
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

+ (PEConnectingLine)connectingLineWithRect:(CGRect)rect1 withRect:(CGRect)rect2 {
    CGPoint midPoint1 = [self midPointOfRect:rect1];
    CGPoint midPoint2 = [self midPointOfRect:rect2];
    PESide side1, side2;
    if ([self intersectsVerticallyWithRect:rect1 andRect:rect2]) {
        if (midPoint1.y < midPoint2.y) {
            side1 = PESideBottom;
            side2 = PESideTop;
        } else {
            side1 = PESideTop;
            side2 = PESideBottom;
        }
    } else {
        if (midPoint1.x < midPoint2.x) {
            side1 = PESideRight;
            side2 = PESideLeft;
        } else {
            side1 = PESideLeft;
            side2 = PESideRight;
        }
    }
    PEConnectedPoint startConnectedPoint = [self connectedPointWithRect:rect1 side:side1];
    PEConnectedPoint endConnectedPoint = [self connectedPointWithRect:rect2 side:side2];
    return PEConnectingLineMake(startConnectedPoint, endConnectedPoint);
}

+ (CGRect)makeRectWithMidpoint:(CGPoint)midpoint size:(CGFloat)size {
    CGFloat halfSize = size / 2.0;
    return CGRectMake(midpoint.x - halfSize, midpoint.y - halfSize, size, size);
}

+ (CGRect)centerSize:(CGSize)size inRect:(CGRect)rect {
    return CGRectMake(rect.origin.x + (rect.size.width - size.width) / 2.0, rect.origin.y + (rect.size.height - size.height) / 2.0, size.width, size.height);
}

+ (CGFloat)distanceBetweenPoint:(CGPoint)point1 andPoint:(CGPoint)point2 {
    return sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2));
}

+ (CGPoint)PDFPointWithAbsPoint:(CGPoint)absPoint artboardsRect:(CGRect)artboardsRect scale:(CGFloat)scale {
    return CGPointMake((absPoint.x - artboardsRect.origin.x) * scale, (artboardsRect.size.height - (absPoint.y - artboardsRect.origin.y)) * scale);
}

+ (PEConnectedPoint)PDFConnectedPointWithAbsConnectedPoint:(PEConnectedPoint)absConnectedPoint artboardsRect:(CGRect)artboardsRect scale:(CGFloat)scale {
    return PEConnectedPointMake([self PDFPointWithAbsPoint:absConnectedPoint.point artboardsRect:artboardsRect scale:scale], absConnectedPoint.side);
}

+ (CGRect)PDFRectWithAbsRect:(CGRect)absRect artboardsRect:(CGRect)artboardsRect scale:(CGFloat)scale {
    return CGRectMake((absRect.origin.x - artboardsRect.origin.x) * scale, (artboardsRect.size.height - (absRect.origin.y - artboardsRect.origin.y)) * scale,
                      absRect.size.width * scale, -absRect.size.height * scale);
}

+ (CGPoint)offsetPDFPoint:(CGPoint)point side:(PESide)side offset:(CGFloat)offset {
    switch (side) {
        case PESideTop:
            return CGPointMake(point.x, point.y + offset);
            
        case PESideRight:
            return CGPointMake(point.x + offset, point.y);
            
        case PESideBottom:
            return CGPointMake(point.x, point.y - offset);
            
        case PESideLeft:
            return CGPointMake(point.x - offset, point.y);
            
        default:
            return point;
    }
}

# pragma mark - Private

+ (CGPoint)midPointOfRect:(CGRect)rect {
    return CGPointMake(rect.origin.x + (rect.size.width / 2.0), rect.origin.y + (rect.size.height / 2.0));
}

+ (BOOL)intersectsVerticallyWithRect:(CGRect)rect1 andRect:(CGRect)rect2 {
    CGFloat x1 = rect1.origin.x + rect1.size.width;
    CGFloat x2 = rect2.origin.x + rect2.size.width;
    return (rect1.origin.x >= rect2.origin.x && rect1.origin.x <= x2) || (x1 >= rect2.origin.x && x1 <= x2);
}

+ (PEConnectedPoint)connectedPointWithRect:(CGRect)rect side:(PESide)side {
    CGPoint point = CGPointZero;
    switch (side) {
        case PESideTop:
            point = CGPointMake(rect.origin.x + rect.size.width / 2.0, rect.origin.y);
            break;
            
        case PESideRight:
            point = CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height / 2.0);
            break;
            
        case PESideBottom:
            point = CGPointMake(rect.origin.x + rect.size.width / 2.0, rect.origin.y + rect.size.height);
            break;
            
        case PESideLeft:
            point = CGPointMake(rect.origin.x, rect.origin.y + rect.size.height / 2.0);
            break;
            
        default:
            break;
    }
    
    return PEConnectedPointMake(point, side);
}
                                    

@end
