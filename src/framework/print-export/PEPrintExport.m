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
#import "PESketchMethods.h"

static const CGFloat kCropMarkLength = 3; // millimeters
static const CGFloat kPageMargin = 15; // millimeters, only applies to Sketch page per PDF page
static const CGFloat kImageResolution = 300; // dpi
static NSString *const kFontName = @"Helvetica Neue";

static const CGFloat kWhiteColor[] = {0, 0, 0, 0, 1};
static const CGFloat kCropMarkColor[] = {0, 0, 0, 1, 1};
static const CGFloat kArtboardNameColor[] = {0, 0, 0, 0.4, 1};
static const CGFloat kPrototypingLinkColor[] = {0, 0.38, 1, 0.04, 1};
static const CGFloat kStartCircleFillColor[] = {0, 0, 0, 0, 1};
static const CGFloat kArtboardShadowBlur = 4;
static const CGFloat kArtboardMinShadowBlur = 1;
static const CGFloat kArtboardShadowColor[] = {0, 0, 0, 1, 0.5};
static const CGSize kArrowSize = {.width = 5, .height = 5};
static const CGFloat kConnectingEndPointOffset = 2;
static const CGFloat kStartCircleDiameter = 3;
static const CGFloat kBackBoxOffset = 3;
static const CGFloat kBackBoxSize = 7;
static const CGFloat kBackBoxCornerRadius = 1.5;
static const CGSize kBackArrowSize = {.width =  2, .height = 4};
static const CGFloat kPrototypingLinkWidth = 0.5;

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
@property (readonly, nonatomic) CGColorSpaceRef colorSpace;

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

+ (void)generatePDFWithDocument:(MSDocument *)document filePath:(NSString *)filePath options:(NSDictionary*)options context:(NSDictionary *)pluginContext {
    PEOptions *typedOptions = [[PEOptions alloc] initWithOptions:options];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        PEPrintExport *printExport = [[PEPrintExport alloc] initWithDocument:document fileURL:fileURL options:typedOptions];
        switch (typedOptions.exportType) {
            case PEExportTypeArtboardPerPage:
                [printExport generateArtboardPerPage];
                break;
                
            case PEExportTypeSketchPagePerPage:
                [printExport generateSketchPagePerPage];
                break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [PESketchMethods displayFlashMessage:@"The PDF has been exported" document:document];
        });
    });
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
        _colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericCMYK);
    }
    return self;
}

- (void)dealloc {
    CFRelease(self.auxiliaryInfo);
    CGColorSpaceRelease(self.colorSpace);
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
    NSColorSpace *nsColorSpace = [[NSColorSpace alloc] initWithCGColorSpace:self.colorSpace];
    for (MSImmutableArtboardGroup *artboard in sortedArtboards) {
        CGContextBeginPage(ctx, NULL);
        [self setColorSpaceWithContext:ctx];
        CGContextSaveGState(ctx);
        if (self.options.hasCropMarks) {
            [self drawCropMarksWithContext:ctx];
        }
        CGSize targetSize = [PEUtils fitSize:artboard.rect.size inSize:self.options.pageSize];
        CGContextSaveGState(ctx);
        CGRect targetRect = CGRectMake((self.mediaBox.size.width - targetSize.width) / 2.0, (self.mediaBox.size.height - targetSize.height) / 2.0, targetSize.width, targetSize.height);
        CGContextTranslateCTM(ctx, targetRect.origin.x, targetRect.origin.y);
        double imageScale = (targetSize.width / 72 * kImageResolution) / artboard.rect.size.width;
        if (imageScale < 1) {
            imageScale = 1;
        }
        CGImageRef artboardImage = [PEUtils imageOfArtboard:artboard scale:imageScale targetColorSpace:nsColorSpace documentData:self.immutableDocumentData];
        CGContextDrawImage(ctx, CGRectMake(0, 0, targetSize.width, targetSize.height), artboardImage);
        CGContextRestoreGState(ctx);
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
    CGSize maxPageSize = CGSizeMake(self.options.pageSize.width - (self.pageMargin * 2), self.options.pageSize.height - (self.pageMargin * 2));
    CGSize targetSize = [PEUtils fitSize:artboardsRect.size inSize:maxPageSize];
    CGPoint origin = CGPointMake((self.mediaBox.size.width - targetSize.width) / 2.0, (self.mediaBox.size.height - targetSize.height) / 2.0);
    CGContextTranslateCTM(ctx, origin.x, origin.y);
    CGFloat scale = targetSize.width / artboardsRect.size.width;
    NSColorSpace *nsColorSpace = [[NSColorSpace alloc] initWithCGColorSpace:self.colorSpace];
    for (MSImmutableArtboardGroup *artboard in page.artboards) {
        CGContextSaveGState(ctx);
        CGContextScaleCTM(ctx, scale, scale);
        CGContextTranslateCTM(ctx, artboard.rect.origin.x - artboardsRect.origin.x, artboardsRect.size.height - (artboard.rect.origin.y - artboardsRect.origin.y + artboard.rect.size.height));
        if (self.options.showArboardShadow) {
            [self drawArtboardShadowWithArtboard:artboard rect:CGRectMake(0, 0, artboard.rect.size.width, artboard.rect.size.height) scale:scale context:ctx];
        }
        double imageScale = ((((targetSize.width / 72) / artboardsRect.size.width) * artboard.rect.size.width) * kImageResolution) / artboard.rect.size.width;
        if (imageScale < 1) {
            imageScale = 1;
        }
        CGImageRef artboardImage = [PEUtils imageOfArtboard:artboard scale:imageScale targetColorSpace:nsColorSpace documentData:self.immutableDocumentData];
        CGContextDrawImage(ctx, CGRectMake(0, 0, artboard.rect.size.width, artboard.rect.size.height), artboardImage);
        CGContextRestoreGState(ctx);
        if (self.options.showPrototypingLinks) {
            [self drawPrototypingLinksWithArtboard:artboard artboards:page.artboards artboardsRect:artboardsRect scale:scale context:ctx];
        }
        if (self.options.showArboardName) {
            CGPoint position = [PEUtils PDFPointWithAbsPoint:CGPointMake(artboard.rect.origin.x + artboard.rect.size.width / 2.0, artboard.rect.origin.y + artboard.rect.size.height + 40)
                                               absBoundsRect:artboardsRect scale:scale];
            [self drawLabel:artboard.name position:position size:22 * scale context:ctx];
        }
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

- (void)drawPrototypingLinksWithArtboard:(MSImmutableArtboardGroup *)artboard artboards:(NSArray<MSImmutableArtboardGroup *> *)artboards artboardsRect:(CGRect)artboardsRect
                                   scale:(CGFloat)scale context:(CGContextRef)ctx {
    NSArray<PEFlowConnection *> *flowConnections = [self buildFlowConnectionsWithArtboard:artboard];
    if (flowConnections.count == 0) {
        return;
    }
    CGContextSaveGState(ctx);
    
    // artboards clipping area
    CGContextBeginPath(ctx);
    CGContextAddRect(ctx, CGRectInfinite);
    for (MSImmutableArtboardGroup *itArtboard in artboards) {
        if (itArtboard != artboard) {
            CGContextAddRect(ctx, [PEUtils PDFRectWithAbsRect:itArtboard.rect absBoundsRect:artboardsRect scale:scale]);
        }
    }
    CGContextEOClip(ctx);
    
    CGContextSetLineWidth(ctx, kPrototypingLinkWidth);
    CGContextSetStrokeColor(ctx, kPrototypingLinkColor);
    
    for (PEFlowConnection *flowConnection in flowConnections) {
        MSImmutableArtboardGroup *destinationArtboard = (MSImmutableArtboardGroup *)[self layerWithID:flowConnection.destinationArtboardID];
        CGRect sourceAbsRect = CGRectMake(artboard.rect.origin.x + flowConnection.frame.origin.x, artboard.rect.origin.y + flowConnection.frame.origin.y,
                                          flowConnection.frame.size.width, flowConnection.frame.size.height);
        CGRect sourceRect = [PEUtils PDFRectWithAbsRect:sourceAbsRect absBoundsRect:artboardsRect scale:scale];
        CGPoint startPoint;
        if (flowConnection.destinationArtboardID != nil) {
            PEConnectingLine connectingLine = [PEUtils connectingLineWithRect:sourceAbsRect withRect:destinationArtboard.rect];
            startPoint = [PEUtils PDFPointWithAbsPoint:connectingLine.startPoint.point absBoundsRect:artboardsRect scale:scale];
            PEConnectedPoint pdfConnectedPoint = [PEUtils PDFConnectedPointWithAbsConnectedPoint:connectingLine.endPoint absBoundsRect:artboardsRect scale:scale];
            CGPoint endPoint = [PEUtils offsetPDFPoint:pdfConnectedPoint.point side:connectingLine.endPoint.side offset:kConnectingEndPointOffset + kArrowSize.height];
            
            // curve
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, startPoint.x, startPoint.y);
            CGFloat deltaX = fabs(startPoint.x - connectingLine.endPoint.point.x);
            CGFloat deltaY = fabs(startPoint.y - connectingLine.endPoint.point.y);
            if (deltaX == 0 || deltaY == 0) {
                CGContextAddLineToPoint(ctx, endPoint.x, endPoint.y);
            } else {
                CGFloat length = [PEUtils distanceBetweenPoint:startPoint andPoint:endPoint] / 3.0;
                CGPoint controlPoint1 = [self calculateControlPointWithPoint:startPoint side:connectingLine.startPoint.side length:length];
                CGPoint controlPoint2 = [self calculateControlPointWithPoint:endPoint side:connectingLine.endPoint.side length:length];
                CGContextAddCurveToPoint(ctx, controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, endPoint.x, endPoint.y);
            }
            CGContextDrawPath(ctx, kCGPathStroke);
            
            // arrow
            [self createArrowPathWithPoint:endPoint side:connectingLine.endPoint.side size:kArrowSize context:ctx];
            CGContextSetFillColor(ctx, kPrototypingLinkColor);
            CGContextDrawPath(ctx, kCGPathFill);
        } else {
            // previous artboard
            startPoint = CGPointMake(sourceRect.origin.x, sourceRect.origin.y + sourceRect.size.height / 2.0);
            
            // line
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, startPoint.x, startPoint.y);
            CGPoint endPoint = CGPointMake(((artboard.rect.origin.x - artboardsRect.origin.x) * scale) - kBackBoxOffset, startPoint.y);
            CGContextAddLineToPoint(ctx, endPoint.x, endPoint.y);
            CGContextDrawPath(ctx, kCGPathStroke);
            
            // box
            CGRect boxRect = CGRectMake(endPoint.x - kBackBoxSize, endPoint.y - (kBackBoxSize / 2.0), kBackBoxSize, kBackBoxSize);
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
    CGContextRestoreGState(ctx);
}

// point is where the curve connects to the arrow i.e. opposite the apex
- (void)createArrowPathWithPoint:(CGPoint)point side:(PESide)side size:(CGSize)size context:(CGContextRef)ctx {
    CGFloat angle = 0;
    switch (side) {
        case PESideTop:
            angle = -M_PI_2;
            break;
            
        case PESideRight:
            angle = M_PI;
            break;
            
        case PESideBottom:
            angle = M_PI_2;
            break;
            
        case PESideLeft:
            angle = 0;
            break;
    }
    [self createArrowPathWithPoint:point angle:angle size:size context:ctx];
}

- (void)createArrowPathWithPoint:(CGPoint)point angle:(CGFloat)angle size:(CGSize)size context:(CGContextRef)ctx {
    CGContextBeginPath(ctx);
    CGFloat halfWidth = size.width / 2.0;
    CGContextMoveToPoint(ctx, cos(angle + M_PI_2) * halfWidth + point.x, sin(angle + M_PI_2) * halfWidth + point.y);
    CGContextAddLineToPoint(ctx, cos(angle - M_PI_2) * halfWidth + point.x, sin(angle - M_PI_2) * halfWidth + point.y);
    CGContextAddLineToPoint(ctx, cos(angle) * size.height + point.x, sin(angle) * size.height + point.y);
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

- (CGPoint)calculateControlPointWithPoint:(CGPoint)point side:(PESide)side length:(CGFloat)length {
    switch (side) {
        case PESideLeft:
            return CGPointMake(point.x - length, point.y);
            
        case PESideRight:
            return CGPointMake(point.x + length, point.y);
            
        case PESideTop:
            return CGPointMake(point.x, point.y + length);
            
        case PESideBottom:
            return CGPointMake(point.x, point.y - length);
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

- (NSArray<PEFlowConnection *> *)buildFlowConnectionsWithArtboard:(MSImmutableArtboardGroup *)artboard {
    NSMutableArray<PEFlowConnection *> *flowConnections = [NSMutableArray new];
    for (MSImmutableLayer *layer in artboard.layers) {
        [self buildFlowConnections:flowConnections layer:layer parentOrigin:CGPointZero];
    }
    return [flowConnections copy];
}

- (void)buildFlowConnections:(NSMutableArray<PEFlowConnection *> *)flowConnections layer:(MSImmutableLayer *)layer
                parentOrigin:(CGPoint)parentOrigin {
    if ([self hasFlowConnectionWithLayer:layer]) {
        PEFlowConnection *flowConnection = [self buildFlowConnectionWithLayer:layer parentOrigin:parentOrigin];
        [flowConnections addObject:flowConnection];
    }
    
    BOOL isSymbolInstance = [layer isMemberOfClass:NSClassFromString(kMSImmutableSymbolInstance)];
    if ([layer isKindOfClass:NSClassFromString(kMSImmutableLayerGroup)] || isSymbolInstance) {
        MSImmutableLayerGroup *layerGroup = nil;
        if (isSymbolInstance) {
            layerGroup = [PESketchMethods detachedLayerGroupRecursively:YES withDocument:self.immutableDocumentData symbolInstance:(MSImmutableSymbolInstance *)layer];
        } else {
            layerGroup = (MSImmutableLayerGroup *)layer;
        }
        for (MSImmutableLayer *childLayer in layerGroup.layers) {
            CGPoint tOrigin = CGPointMake(parentOrigin.x + layerGroup.rect.origin.x, parentOrigin.y + layerGroup.rect.origin.y);
            [self buildFlowConnections:flowConnections layer:childLayer parentOrigin:tOrigin];
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
    return [PESketchMethods immutableLayerWithID:layerID documentData:self.documentData];
}

@end
