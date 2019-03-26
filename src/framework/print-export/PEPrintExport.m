//
//  PEPrintExport.m
//  print-export
//
//  Created by Mark Horgan on 19/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "PEPrintExport.h"
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import "PEOptions.h"
#import "PEUtils.h"
#import "MSDocument.h"
#import "MSImmutableDocumentData.h"
#import "MSConstants.h"
#import "MSImmutableLayer.h"
#import "MSImmutableFlowConnection.h"
#import "PEFlowConnection.h"
#import "types.h"
#import <NSLogger/NSLogger.h>

static const CGFloat kCropMarkLength = 5; // millimeters
static const CGFloat kPageMargin = 20; // millimeters
static NSString *const kFontName = @"Helvetica Neue";
static const CGFloat kControlPointDistance = 200;
static const CGFloat kConnectingEndPointOffset = 6;
static const CGFloat kArrowLength = 10;
static const CGFloat kArrowWidth = kArrowLength;
static const CGFloat kStartCircleDiameter = 6;
static const CGFloat kHotspotCornerRadius = 4;
static const CGFloat kBackLineLength = 60;
static const CGFloat kBackBoxSize = 17;
static const CGFloat kBackBoxCornerRadius = 3;
static const CGSize kBackArrowSize = {.width =  4, .height = 9};
static const CGFloat kWhiteColor[] = {0, 0, 0, 0, 1};
static const CGFloat kCropMarkColor[] = {0, 0, 0, 1, 1};
static const CGFloat kArtboardNameColor[] = {0, 0, 0, 0.4, 1};
static const CGFloat kPrototypingLinkColor[] = {0, 0.38, 1, 0.04, 1};
static const CGFloat kStartCircleFillColor[] = {0, 0, 0, 0, 1};
static const CGFloat kHotspotColor[] = {0, 0.38, 1, 0.04, 0.3};
static const CGFloat kArtboardShadowBlur = 5;
static const CGFloat kArtboardMinShadowBlur = 1;
static const CGFloat kArtboardShadowColor[] = {0, 0, 0, 1, 0.5};

@interface PEPrintExport()

@property (readonly, nonatomic) NSString *symbolsPageID;
@property (readonly, nonatomic) NSURL *fileURL;
@property (readonly, nonatomic) PEOptions *options;
@property (readonly, nonatomic) MSDocumentData *documentData;
@property (readonly, nonatomic) MSImmutableDocumentData *immutableDocumentData;
@property (readonly, nonatomic) CFDictionaryRef auxiliaryInfo;
@property (readonly, nonatomic) CGRect mediaBox;
@property (readonly, nonatomic) CGRect bleedBox;
@property (readonly, nonatomic) CGRect trimBox;
@property (readonly, nonatomic) CGFloat slugBleed;
@property (readonly, nonatomic) CGFloat cropMarkLength;
@property (readonly, nonatomic) CGFloat pageMargin;
@property (readonly, nonatomic) CGSize maxPageSize;
@property (strong, nonatomic) __attribute__((NSObject)) CGColorSpaceRef colorSpace;

@end

@implementation PEPrintExport

+ (void)onShutdown:(NSDictionary *)context {
    NSString *scriptPath = context[@"scriptPath"];
    NSString *frameworkBasePath = [scriptPath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Resources"];
    NSString *frameworkPath = [[frameworkBasePath stringByAppendingPathComponent:@"print_export.framework"] stringByAppendingPathComponent:@"print_export"];
    void *frameworkHandle = dlopen([frameworkPath UTF8String], RTLD_LAZY);
    if (frameworkHandle != nil) {
        int result;
        do {
            result = dlclose(frameworkHandle);
        } while (result != -1);
    } else {
        NSLog(@"Couldn't load framework: %@", frameworkPath);
    }
}

+ (void)generatePDFWithDocument:(MSDocument *)document filePath:(NSString *)filePath options:(NSDictionary*)options {
    PEOptions *typedOptions = [[PEOptions alloc] initWithOptions:options];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    PEPrintExport *printExport = [[PEPrintExport alloc] initWithDocument:document fileURL:fileURL options:typedOptions];
    switch (typedOptions.exportType) {
        case PEExportTypeArtboardPerPage:
            [printExport generateArtboardPerPage];
            break;
            
        case PEExportTypeSketchPagePerPage:
            [printExport generateSketchPagePerPage];
            break;
    }
}

# pragma mark - Private

- (instancetype)initWithDocument:(MSDocument*)document fileURL:(NSURL *)fileURL options:(PEOptions*)options {
    if (self = [super init]) {
        _documentData = document.documentData;
        _immutableDocumentData = document.documentData.immutableModelObject;
        _fileURL = fileURL;
        _options = options;
        _symbolsPageID = [document.documentData symbolsPage].objectID;
        _auxiliaryInfo = [self createAuxiliaryInfoWithOptions:self.options];
        _pageMargin = PEMMToUnit(kPageMargin);
        _slugBleed = self.options.slug + self.options.bleed;
        _maxPageSize = CGSizeMake(self.options.pageSize.width - (self.pageMargin * 2), self.options.pageSize.height - (self.pageMargin * 2));
        self.colorSpace = CGColorSpaceCreateDeviceCMYK();
    }
    return self;
}

- (void)dealloc {
    CFRelease(self.auxiliaryInfo);
}

- (CGContextRef)createContext {
    CGRect mediaBox = self.mediaBox;
    CGContextRef ctx = CGPDFContextCreateWithURL((__bridge CFURLRef)self.fileURL, &mediaBox, self.auxiliaryInfo);
    if (!ctx) {
        NSLog(@"Couldn't create PDF context");
        return NULL;
    }
    return ctx;
}

- (void)setColorSpaceWithContext:(CGContextRef)ctx {
    CGContextSetFillColorSpace(ctx, self.colorSpace);
    CGContextSetStrokeColorSpace(ctx, self.colorSpace);
}

- (void)generateArtboardPerPage {
    CGContextRef ctx = [self createContext];
    if (!ctx) {
        return;
    }
    switch (self.options.scope) {
        case PEScopeAllPages:
            for (MSImmutablePage *page in self.immutableDocumentData.pages) {
                if (![page.objectID isEqualToString:self.symbolsPageID]) {
                    [self generateArtboardsWithPage:page context:ctx];
                }
            }
            break;
            
        case PEScopeCurrentPage:
            [self generateArtboardsWithPage:self.immutableDocumentData.currentPage context:ctx];
            break;
    }
    CGContextRelease(ctx);
}

- (void)generateSketchPagePerPage {
    CGContextRef ctx = [self createContext];
    if (!ctx) {
        return;
    }
    switch (self.options.scope) {
        case PEScopeAllPages:
            for (MSImmutablePage *page in self.immutableDocumentData.pages) {
                if (![page.objectID isEqualToString:self.symbolsPageID]) {
                    [self generateSketchPageWithPage:page context:ctx];
                }
            }
            break;
            
        case PEScopeCurrentPage:
            [self generateSketchPageWithPage:self.immutableDocumentData.currentPage context:ctx];
            break;
    }
    CGContextRelease(ctx);
}

- (CGFloat)cropMarkLength {
    if (kCropMarkLength <= self.options.slug) {
        return PEMMToUnit(kCropMarkLength);
    } else {
        return self.options.slug;
    }
}

- (void)generateArtboardsWithPage:(MSImmutablePage*)page context:(CGContextRef)ctx {
    NSArray<MSImmutableArtboardGroup*> *sortedArtboards = [page.artboards sortedArrayUsingComparator:^(MSImmutableArtboardGroup *artboard1, MSImmutableArtboardGroup *artboard2) {
        if (artboard1.rect.origin.y < artboard2.rect.origin.y) {
            return NSOrderedAscending;
        } else if (artboard1.rect.origin.y > artboard2.rect.origin.y) {
            return NSOrderedDescending;
        } else {
            if (artboard1.rect.origin.x < artboard2.rect.origin.x) {
                return NSOrderedAscending;
            } else if (artboard1.rect.origin.x > artboard2.rect.origin.x) {
                return NSOrderedDescending;
            }
        }
        return NSOrderedSame;
    }];
    for (MSImmutableArtboardGroup *artboard in sortedArtboards) {
        CGContextBeginPage(ctx, NULL);
        [self setColorSpaceWithContext:ctx];
        CGContextSaveGState(ctx);
        if (self.options.hasCropMarks) {
            [self drawCropMarksWithContext:ctx];
        }
        CGPDFDocumentRef artboardPDF = [PEUtils createPDFPageOfArtboard:artboard documentData:self.immutableDocumentData];
        CGPDFPageRef artboardPDFPage = CGPDFDocumentGetPage(artboardPDF, 1);
        CGSize targetSize = [PEUtils fitSize:artboard.rect.size inSize:self.maxPageSize];
        CGRect artboardPDFRect = CGPDFPageGetBoxRect(artboardPDFPage, kCGPDFCropBox);
        CGContextSaveGState(ctx);
        CGRect targetRect = CGRectMake((self.mediaBox.size.width - targetSize.width) / 2.0, (self.mediaBox.size.height - targetSize.height) / 2.0, targetSize.width, targetSize.height);
        CGContextTranslateCTM(ctx, targetRect.origin.x, targetRect.origin.y);
        CGContextScaleCTM(ctx, targetSize.width / artboardPDFRect.size.width, targetSize.height / artboardPDFRect.size.height);
        if (self.options.showArboardShadow) {
            [self drawArtboardShadowWithArtboard:artboard rect:CGRectMake(0, 0, artboard.rect.size.width, artboard.rect.size.height) scale:1 context:ctx];
        }
        CGContextDrawPDFPage(ctx, artboardPDFPage);
        CFRelease(artboardPDF);
        CGContextRestoreGState(ctx);
        if (self.options.showArboardName) {
            [self drawLabel:artboard.name position:CGPointMake(targetRect.origin.x + targetRect.size.width / 2.0, targetRect.origin.y - 30) size:12 context:ctx];
        }
        CGContextRestoreGState(ctx);
        CGContextEndPage(ctx);
    }
}

- (void)generateSketchPageWithPage:(MSImmutablePage*)page context:(CGContextRef)ctx {
    CGContextBeginPage(ctx, NULL);
    [self setColorSpaceWithContext:ctx];
    CGContextSaveGState(ctx);
    if (self.options.hasCropMarks) {
        [self drawCropMarksWithContext:ctx];
    }
    CGRect artboardsRect = [self boundsOfArtboardsInPage:page];
    CGSize targetSize = [PEUtils fitSize:artboardsRect.size inSize:self.maxPageSize];
    CGPoint origin = CGPointMake((self.mediaBox.size.width - targetSize.width) / 2.0, (self.mediaBox.size.height - targetSize.height) / 2.0);
    CGContextTranslateCTM(ctx, origin.x, origin.y);
    CGFloat scale = targetSize.width / artboardsRect.size.width;
    CGContextScaleCTM(ctx, scale, scale);
    for (MSImmutableArtboardGroup *artboard in page.artboards) {
        CGPDFDocumentRef artboardPDF = [PEUtils createPDFPageOfArtboard:artboard documentData:self.immutableDocumentData];
        CGPDFPageRef artboardPDFPage = CGPDFDocumentGetPage(artboardPDF, 1);
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, artboard.rect.origin.x - artboardsRect.origin.x, artboardsRect.size.height - (artboard.rect.origin.y - artboardsRect.origin.y + artboard.rect.size.height));
        if (self.options.showArboardShadow) {
            [self drawArtboardShadowWithArtboard:artboard rect:CGRectMake(0, 0, artboard.rect.size.width, artboard.rect.size.height) scale:scale context:ctx];
        }
        CGContextDrawPDFPage(ctx, artboardPDFPage);
        CFRelease(artboardPDF);
        if (self.options.showArboardName) {
            [self drawLabel:artboard.name position:CGPointMake(artboard.rect.size.width / 2.0, -40) size:18 context:ctx];
        }
        CGContextRestoreGState(ctx);
    }
    if (self.options.showPrototypingLinks) {
        CGContextConcatCTM(ctx, CGAffineTransformMake(1, 0, 0, -1, 0, artboardsRect.size.height));
        [self drawPrototypingLinksWithPage:page artboardsOrigin:artboardsRect.origin context:ctx];
    }
    CGContextRestoreGState(ctx);
    CGContextEndPage(ctx);
}

- (void)drawCropMarksWithContext:(CGContextRef)ctx {
    CGContextSaveGState(ctx);
    CGFloat x0 = self.options.slug;
    CGFloat x1 = self.options.slug + self.options.bleed;
    CGFloat x2 = x1 + self.options.pageSize.width;
    CGFloat x3 = x2 + self.options.bleed;
    CGFloat y0 = x0;
    CGFloat y1 = x1;
    CGFloat y2 = y1 + self.options.pageSize.height;
    CGFloat y3 = y2 + self.options.bleed;
    CGPoint points[] = {
        x1, y0,
        x1, y0 - self.cropMarkLength,
        
        x2, y0,
        x2, y0 - self.cropMarkLength,
        
        x0, y1,
        x0 - self.cropMarkLength, y1,
        
        x3, y1,
        x3 + self.cropMarkLength, y1,
        
        x0, y2,
        x0 - self.cropMarkLength, y2,
        
        x3, y2,
        x3 + self.cropMarkLength, y2,
        
        x1, y3,
        x1, y3 + self.cropMarkLength,
        
        x2, y3,
        x2, y3 + self.cropMarkLength
    };
    CGContextSetLineWidth(ctx, 0.5);
    CGContextSetStrokeColor(ctx, kCropMarkColor);
    CGContextStrokeLineSegments(ctx, points, 16);
}

- (void)drawArtboardShadowWithArtboard:(MSImmutableArtboardGroup *)artboard rect:(CGRect)artboardRect scale:(CGFloat)scale context:(CGContextRef)ctx {
    CGContextSaveGState(ctx);
    CGColorRef color = CGColorCreate(self.colorSpace, kArtboardShadowColor);
    CGFloat blur = scale < 0.1 ? kArtboardMinShadowBlur : kArtboardShadowBlur;
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 0), blur, color);
    CGColorRelease(color);
    CGContextSetFillColor(ctx, kWhiteColor);
    CGContextFillRect(ctx, artboardRect);
    CGContextRestoreGState(ctx);
}

- (void)drawLabel:(NSString*)label position:(CGPoint)position size:(CGFloat)size context:(CGContextRef)ctx {
    CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)kFontName, size, NULL);
    CGColorRef color = CGColorCreate(self.colorSpace, kArtboardNameColor);
    CFStringRef keys[] = {kCTFontAttributeName, kCTForegroundColorAttributeName};
    CFTypeRef values[] = {font, color};
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)&keys, (const void**)&values, sizeof(keys) / sizeof(keys[0]),
                                                    &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef)label, attributes);
    CFRelease(attributes);
    CTLineRef line = CTLineCreateWithAttributedString(attrString);
    CFRelease(attrString);
    CGRect lineBounds = CTLineGetImageBounds(line, ctx);
    CGContextSetTextPosition(ctx, position.x - lineBounds.size.width / 2.0, position.y);
    CTLineDraw(line, ctx);
    CFRelease(line);
    CGColorRelease(color);
    CFRelease(font);
}

- (void)drawPrototypingLinksWithPage:(MSImmutablePage *)page artboardsOrigin:(CGPoint)artboardsOrigin context:(CGContextRef)ctx {
    NSDictionary<NSString *, NSArray<PEFlowConnection *> *> *flowConnectionsByArtboardID = [self buildFlowConnectionsWithPage:page];
    
    CGContextSaveGState(ctx);
    CGContextSetLineWidth(ctx, 1);
    CGContextSetStrokeColor(ctx, kPrototypingLinkColor);
    for (MSImmutableArtboardGroup *artboard in page.artboards) {
        NSArray<PEFlowConnection *> *flowConnections = flowConnectionsByArtboardID[artboard.objectID];
        for (PEFlowConnection *flowConnection in flowConnections) {
            MSImmutableArtboardGroup *destinationArtboard = (MSImmutableArtboardGroup *)[self layerWithID:flowConnection.destinationArtboardID];
            CGRect sourceRect = CGRectMake(artboard.rect.origin.x - artboardsOrigin.x + flowConnection.frame.origin.x,
                                           artboard.rect.origin.y - artboardsOrigin.y + flowConnection.frame.origin.y,
                                           flowConnection.frame.size.width, flowConnection.frame.size.height);
            if (flowConnection.type == PEFlowConnectionTypeHotspot) {
                // hotspot
                [self createRoundedRectanglePathWithRect:sourceRect radius:kHotspotCornerRadius context:ctx];
                CGContextSetFillColor(ctx, kHotspotColor);
                CGContextDrawPath(ctx, kCGPathFillStroke);
            }
            
            CGPoint startPoint;
            if (flowConnection.destinationArtboardID != nil) {
                CGRect destinationRect = CGRectMake(destinationArtboard.rect.origin.x - artboardsOrigin.x,
                                                    destinationArtboard.rect.origin.y - artboardsOrigin.y,
                                                    destinationArtboard.rect.size.width,
                                                    destinationArtboard.rect.size.height);
                PEConnectingLine connectingLine = [PEUtils connectingLineWithRect:sourceRect withRect:destinationRect endOffset:kConnectingEndPointOffset + kArrowLength];
                startPoint = connectingLine.startPoint.point;
                
                // curve
                CGContextBeginPath(ctx);
                CGContextMoveToPoint(ctx, startPoint.x, startPoint.y);
                CGFloat deltaX = fabs(connectingLine.startPoint.point.x - connectingLine.endPoint.point.x);
                CGFloat deltaY = fabs(connectingLine.startPoint.point.y - connectingLine.endPoint.point.y);
                if (deltaX == 0 || deltaY == 0) {
                    CGContextAddLineToPoint(ctx, connectingLine.endPoint.point.x, connectingLine.endPoint.point.y);
                } else {
                    CGFloat length = [PEUtils distanceBetweenPoint:connectingLine.startPoint.point andPoint:connectingLine.endPoint.point] / 3.0;
                    CGPoint controlPoint1 = [self calculateControlPointWithConnectedPoint:connectingLine.startPoint length:length];
                    CGPoint controlPoint2 = [self calculateControlPointWithConnectedPoint:connectingLine.endPoint length:length];
                    CGContextAddCurveToPoint(ctx, controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, connectingLine.endPoint.point.x, connectingLine.endPoint.point.y);
                }
                CGContextDrawPath(ctx, kCGPathStroke);
                
                // arrow
                [self createArrowPathWithPoint:connectingLine.endPoint.point side:connectingLine.endPoint.side length:kArrowLength width:kArrowWidth context:ctx];
                CGContextSetFillColor(ctx, kPrototypingLinkColor);
                CGContextDrawPath(ctx, kCGPathFill);
            } else {
                // previous artboard
                startPoint = CGPointMake(sourceRect.origin.x, sourceRect.origin.y + sourceRect.size.height / 2.0);
                
                // line
                CGContextBeginPath(ctx);
                CGContextMoveToPoint(ctx, startPoint.x, startPoint.y);
                CGContextAddLineToPoint(ctx, startPoint.x - kBackLineLength, startPoint.y);
                CGContextDrawPath(ctx, kCGPathStroke);
                
                // box
                CGRect boxRect = CGRectMake(startPoint.x - kBackLineLength - kBackBoxSize, startPoint.y - (kBackBoxSize / 2.0), kBackBoxSize, kBackBoxSize);
                [self createRoundedRectanglePathWithRect:boxRect radius:kBackBoxCornerRadius context:ctx];
                CGContextSetFillColor(ctx, kPrototypingLinkColor);
                CGContextDrawPath(ctx, kCGPathFill);
                
                // arrow
                CGRect arrowRect = [PEUtils centerSize:kBackArrowSize inRect:boxRect];
                CGContextBeginPath(ctx);
                CGContextMoveToPoint(ctx, arrowRect.origin.x + arrowRect.size.width, arrowRect.origin.y);
                CGContextAddLineToPoint(ctx, arrowRect.origin.x, arrowRect.origin.y + arrowRect.size.height / 2.0);
                CGContextAddLineToPoint(ctx, arrowRect.origin.x + arrowRect.size.width, arrowRect.origin.y + arrowRect.size.height);
                CGContextSetStrokeColor(ctx, kWhiteColor);
                CGContextDrawPath(ctx, kCGPathStroke);
            }
            
            // start circle
            CGContextBeginPath(ctx);
            CGContextAddEllipseInRect(ctx, [PEUtils makeRectWithMidpoint:startPoint size:kStartCircleDiameter]);
            CGContextSetFillColor(ctx, kStartCircleFillColor);
            CGContextSetStrokeColor(ctx, kPrototypingLinkColor);
            CGContextDrawPath(ctx, kCGPathFillStroke);
        }
    }
    CGContextRestoreGState(ctx);
}

// point is where the curve connects to the arrow i.e. opposite the apex
- (void)createArrowPathWithPoint:(CGPoint)point side:(PESide)side length:(CGFloat)length width:(CGFloat)width context:(CGContextRef)ctx {
    CGFloat angle = 0;
    switch (side) {
        case PESideTop:
            angle = M_PI_2;
            break;
            
        case PESideRight:
            angle = M_PI;
            break;
            
        case PESideBottom:
            angle = - M_PI_2;
            break;
            
        case PESideLeft:
            angle = 0;
            break;
    }
    [self createArrowPathWithPoint:point angle:angle length:length width:width context:ctx];
}

- (void)createArrowPathWithPoint:(CGPoint)point angle:(CGFloat)angle length:(CGFloat)length width:(CGFloat)width context:(CGContextRef)ctx {
    CGContextBeginPath(ctx);
    CGFloat halfWidth = width / 2.0;
    CGContextMoveToPoint(ctx, cos(angle + M_PI_2) * halfWidth + point.x, sin(angle + M_PI_2) * halfWidth + point.y);
    CGContextAddLineToPoint(ctx, cos(angle - M_PI_2) * halfWidth + point.x, sin(angle - M_PI_2) * halfWidth + point.y);
    CGContextAddLineToPoint(ctx, cos(angle) * length + point.x, sin(angle) * length + point.y);
    CGContextClosePath(ctx);
}

- (void)createRoundedRectanglePathWithRect:(CGRect)rect radius:(CGFloat)radius context:(CGContextRef)ctx {
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat midX = CGRectGetMidX(rect);
    CGFloat midY = CGRectGetMidY(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat maxY = CGRectGetMaxY(rect);
    
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, minX, midY);
    CGContextAddArcToPoint(ctx, minX, minY, midX, minY, radius);
    CGContextAddArcToPoint(ctx, maxX, minY, maxX, midY, radius);
    CGContextAddArcToPoint(ctx, maxX, maxY, midX, maxY, radius);
    CGContextAddArcToPoint(ctx, minX, maxY, minX, midY, radius);
    CGContextClosePath(ctx);
}

- (CGPoint)calculateControlPointWithConnectedPoint:(PEConnectedPoint)connectedPoint length:(CGFloat)length {
    switch (connectedPoint.side) {
        case PESideLeft:
            return CGPointMake(connectedPoint.point.x - length, connectedPoint.point.y);
            
        case PESideRight:
            return CGPointMake(connectedPoint.point.x + length, connectedPoint.point.y);
            
        case PESideTop:
            return CGPointMake(connectedPoint.point.x, connectedPoint.point.y - length);
            
        case PESideBottom:
            return CGPointMake(connectedPoint.point.x, connectedPoint.point.y + length);
    }
}

- (CGPoint)getControlPointWithConnectedPoint:(PEConnectedPoint)connectedPoint point:(CGPoint)point deltaX:(CGFloat)deltaX deltaY:(CGFloat)deltaY {
    if (connectedPoint.side == PESideLeft || connectedPoint.side == PESideRight) {
        
        if (connectedPoint.point.x < point.x) {
            return NSMakePoint(connectedPoint.point.x + kControlPointDistance, connectedPoint.point.y);
        } else {
            return NSMakePoint(connectedPoint.point.x - kControlPointDistance, connectedPoint.point.y);
        }
    } else {
        if (connectedPoint.point.y < point.y) {
            return NSMakePoint(connectedPoint.point.x, connectedPoint.point.y + kControlPointDistance);
        } else {
            return NSMakePoint(connectedPoint.point.x, connectedPoint.point.y - kControlPointDistance);
        }
    }
}

- (CFDictionaryRef)createAuxiliaryInfoWithOptions:(PEOptions *)options {
    _mediaBox = CGRectMake(0, 0, self.options.pageSize.width + ((self.options.slug + self.options.bleed) * 2), self.options.pageSize.height + ((self.options.slug + self.options.bleed) * 2));
    _bleedBox = CGRectMake(self.options.slug, self.options.slug, self.options.pageSize.width + (self.options.bleed * 2), self.options.pageSize.height + (self.options.bleed * 2));
    _trimBox = CGRectMake(self.options.slug + self.options.bleed, self.options.slug + self.options.bleed, self.options.pageSize.width, self.options.pageSize.height);
    
    CFMutableDictionaryRef info = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    CGRect mediaBox = self.mediaBox;
    CFDataRef mediaBoxData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&mediaBox, sizeof(mediaBox));
    CFDictionarySetValue(info, kCGPDFContextMediaBox, mediaBoxData);
    CFRelease(mediaBoxData);
    
    CGRect bleedBox = self.bleedBox;
    CFDataRef bleedBoxData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&bleedBox, sizeof(bleedBox));
    CFDictionarySetValue(info, kCGPDFContextMediaBox, bleedBoxData);
    CFRelease(bleedBoxData);
    
    CGRect trimBox = self.trimBox;
    CFDataRef trimBoxData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&trimBox, sizeof(trimBox));
    CFDictionarySetValue(info, kCGPDFContextTrimBox, trimBoxData);
    CFRelease(trimBoxData);
    
    return info;
}

- (CGRect)boundsOfArtboardsInPage:(MSImmutablePage *)page {
    NSNumber *minX, *minY, *maxX, *maxY;
    for (MSImmutableArtboardGroup *artboard in page.artboards) {
        if (minX == nil || artboard.rect.origin.x < minX.doubleValue) {
            minX = [NSNumber numberWithDouble:artboard.rect.origin.x];
        }
        if (minY == nil || artboard.rect.origin.y < minY.doubleValue) {
            minY = [NSNumber numberWithDouble:artboard.rect.origin.y];
        }
        if (maxX == nil || artboard.rect.origin.x + artboard.rect.size.width > maxX.doubleValue) {
            maxX = [NSNumber numberWithDouble:artboard.rect.origin.x + artboard.rect.size.width];
        }
        if (maxY == nil || artboard.rect.origin.y + artboard.rect.size.height > maxY.doubleValue) {
            maxY = [NSNumber numberWithDouble:artboard.rect.origin.y + artboard.rect.size.height];
        }
    }
    return CGRectMake(minX.doubleValue, minY.doubleValue, maxX.doubleValue - minX.doubleValue, maxY.doubleValue - minY.doubleValue);
}

- (NSDictionary<NSString *, NSArray<PEFlowConnection *> *> *)buildFlowConnectionsWithPage:(MSImmutablePage *)page {
    NSMutableDictionary<NSString *, NSMutableArray<PEFlowConnection *> *> *flowConnectionsByArtboardID = [NSMutableDictionary new];
    for (MSImmutableArtboardGroup *artboard in page.artboards) {
        for (MSImmutableLayer *layer in artboard.layers) {
            [self buildFlowConnections:flowConnectionsByArtboardID layer:layer parentOrigin:CGPointZero parentArtboardID:artboard.objectID];
        }
    }
    return [flowConnectionsByArtboardID copy];
}

- (void)buildFlowConnections:(NSMutableDictionary<NSString *, NSMutableArray<PEFlowConnection *> *> *)flowConnectionsByArtboardID layer:(MSImmutableLayer *)layer
                parentOrigin:(CGPoint)parentOrigin parentArtboardID:(NSString *)parentArtboardID {
    if ([self hasFlowConnectionWithLayer:layer]) {
        PEFlowConnection *flowConnection = [self buildFlowConnectionWithLayer:layer parentOrigin:parentOrigin];
        NSMutableArray *flowConnections = flowConnectionsByArtboardID[parentArtboardID];
        if (flowConnections == nil) {
            flowConnections = [NSMutableArray new];
            flowConnectionsByArtboardID[parentArtboardID] = flowConnections;
        }
        [flowConnections addObject:flowConnection];
    }
        
    if ([layer isKindOfClass:NSClassFromString(kMSImmutableLayerGroup)]) {
        MSImmutableLayerGroup *layerGroup = (MSImmutableLayerGroup *)layer;
        for (MSImmutableLayer *childLayer in layerGroup.layers) {
            CGPoint childParentOrigin = CGPointMake(parentOrigin.x + childLayer.rect.origin.x, parentOrigin.y + childLayer.rect.origin.y);
            [self buildFlowConnections:flowConnectionsByArtboardID layer:childLayer parentOrigin:childParentOrigin parentArtboardID:parentArtboardID];
        }
    }
}
                                            
- (PEFlowConnection *)buildFlowConnectionWithLayer:(MSImmutableLayer *)layer parentOrigin:(CGPoint)parentOrigin {
    CGRect frame = CGRectMake(parentOrigin.x + layer.rect.origin.x, parentOrigin.y + layer.rect.origin.y, layer.rect.size.width, layer.rect.size.height);
    PEFlowConnectionType type;
    if ([layer isMemberOfClass:NSClassFromString(kMSImmutableHotspotLayer)]) {
        type = PEFlowConnectionTypeHotspot;
    } else {
        type = PEFlowConnectionTypeLayer;
    }
    NSString *destinationArtboardID = layer.flow.isBackAction ? nil : layer.flow.destinationArtboardID;
    return [[PEFlowConnection alloc] initWithType:type frame:frame destinationArtboardID:destinationArtboardID];
}

- (BOOL)hasFlowConnectionWithLayer:(MSImmutableLayer *)layer {
    return layer.flow != nil && ![layer.flow.destinationArtboardID isEqualToString:@""];
}

- (MSImmutableLayer *)layerWithID:(NSString *)layerID {
    return [PEUtils immutableLayerWithID:layerID documentData:self.documentData];
}

@end
