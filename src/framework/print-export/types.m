//
//  types.m
//  print-export
//
//  Created by Mark Horgan on 25/03/2019.
//  Copyright © 2019 Sketch. All rights reserved.
//

#import "types.h"

PELine PELineMake(CGPoint startPoint, CGPoint endPoint) {
    PELine line;
    line.startPoint = startPoint;
    line.endPoint = endPoint;
    return line;
}

PEConnectedPoint PEConnectedPointMake(CGPoint point, PESide side) {
    PEConnectedPoint connectedPoint;
    connectedPoint.point = point;
    connectedPoint.side = side;
    return connectedPoint;
}

PEConnectingLine PEConnectingLineMake(PEConnectedPoint startConnectedPoint, PEConnectedPoint endConnectedPoint) {
    PEConnectingLine connectingLine;
    connectingLine.startPoint = startConnectedPoint;
    connectingLine.endPoint = endConnectedPoint;
    return connectingLine;
}
