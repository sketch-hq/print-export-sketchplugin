//
//  types.h
//  print-export
//
//  Created by Mark Horgan on 20/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, PEExportType) {
    PEExportTypeArtboardPerPage,
    PEExportTypeSketchPagePerPage
};

typedef NS_ENUM(NSUInteger, PEScope) {
    PEScopeCurrentPage,
    PEScopeAllPages
};

typedef NS_ENUM(NSUInteger, PEOrientation) {
    PEOrientationPortrait,
    PEOrrientationLandscape
};

typedef NS_ENUM(NSUInteger, PEUnitType) {
    PEUnitTypeMM,
    PEUnitTypeInch
};

typedef NS_ENUM(NSUInteger, PEFlowConnectionType) {
    PEFlowConnectionTypeHotspot,
    PEFlowConnectionTypeLayer
};

typedef NS_ENUM(NSUInteger, PESide) {
    PESideTop,
    PESideRight,
    PESideBottom,
    PESideLeft
};

typedef struct {
    CGPoint startPoint;
    CGPoint endPoint;
} PELine;

typedef struct {
    CGPoint point;
    PESide side;
} PEConnectedPoint;

typedef struct {
    PEConnectedPoint startPoint;
    PEConnectedPoint endPoint;
} PEConnectingLine;

extern PELine PELineMake(CGPoint startPoint, CGPoint endPoint);
extern PEConnectedPoint PEConnectedPointMake(CGPoint point, PESide side);
extern PEConnectingLine PEConnectingLineMake(PEConnectedPoint startConnectedPoint, PEConnectedPoint endConnectedPoint);
