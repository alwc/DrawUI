//
//  MMCurveToPathElement.m
//  MMDrawUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import "MMCurveToPathElement.h"
#import "UIColor+MMDrawUI.h"
#import "MMAbstractBezierPathElement-Protected.h"
#import "MMMoveToPathElement.h"
#import "Constants.h"
#import "MMVector.h"

#define kDivideStepBy 1.5
#define kAbsoluteMinWidth 0.5


@implementation MMCurveToPathElement {
    CGRect _boundsCache;
    // cache the hash, since it's expenseive to calculate
    NSUInteger _hashCache;
    CGFloat *_subBezierlengthCache;
    CGFloat _length;
    UIBezierPath *_borderPath;
}

- (id)initWithStart:(CGPoint)start
         andCurveTo:(CGPoint)curveTo
        andControl1:(CGPoint)ctrl1
        andControl2:(CGPoint)ctrl2
{
    if (self = [super initWithStart:start]) {
        _curveTo = curveTo;
        _ctrl1 = ctrl1;
        _ctrl2 = ctrl2;

        NSUInteger prime = 31;
        _hashCache = 1;
        _hashCache = prime * _hashCache + [self startPoint].x;
        _hashCache = prime * _hashCache + [self startPoint].y;
        _hashCache = prime * _hashCache + _curveTo.x;
        _hashCache = prime * _hashCache + _curveTo.y;
        _hashCache = prime * _hashCache + _ctrl1.x;
        _hashCache = prime * _hashCache + _ctrl1.y;
        _hashCache = prime * _hashCache + _ctrl2.x;
        _hashCache = prime * _hashCache + _ctrl2.y;

        _boundsCache.origin = CGPointNotFound;
        _subBezierlengthCache = nil;
    }
    return self;
}


+ (id)elementWithStart:(CGPoint)start
            andCurveTo:(CGPoint)curveTo
           andControl1:(CGPoint)ctrl1
           andControl2:(CGPoint)ctrl2
{
    return [[MMCurveToPathElement alloc] initWithStart:start andCurveTo:curveTo andControl1:ctrl1 andControl2:ctrl2];
}

+ (id)elementWithStart:(CGPoint)start andLineTo:(CGPoint)point
{
    return [MMCurveToPathElement elementWithStart:start andCurveTo:point andControl1:start andControl2:point];
}

/**
 * the length along the curve of this element.
 * since it's a curve, this will be longer than
 * the straight distance between start/end points
 */
- (CGFloat)lengthOfElement
{
    if (_length)
        return _length;

    CGPoint bez[4];
    bez[0] = [self startPoint];
    bez[1] = _ctrl1;
    bez[2] = _ctrl2;
    bez[3] = _curveTo;

    _length = lengthOfBezier(bez, .1);
    return _length;
}

- (CGPoint)cgPointDiff:(CGPoint)point1 withPoint:(CGPoint)point2
{
    return CGPointMake(point1.x - point2.x, point1.y - point2.y);
}

- (CGFloat)angleOfStart
{
    return [self angleBetweenPoint:[self startPoint] andPoint:_ctrl1];
}

- (CGFloat)angleOfEnd
{
    CGFloat possibleRet = [self angleBetweenPoint:_ctrl2 andPoint:_curveTo];
    CGFloat start = [self angleOfStart];
    if (ABS(start - possibleRet) > M_PI) {
        CGFloat rotateRight = possibleRet + 2 * M_PI;
        CGFloat rotateLeft = possibleRet - 2 * M_PI;
        if (ABS(start - rotateRight) > M_PI) {
            return rotateLeft;
        } else {
            return rotateRight;
        }
    }
    return possibleRet;
}

- (CGPoint)endPoint
{
    return self.curveTo;
}

- (CGRect)bounds
{
    if (CGPointEqualToPoint(_boundsCache.origin, CGPointNotFound)) {
        CGFloat minX = MIN(MIN(MIN([self startPoint].x, _curveTo.x), _ctrl1.x), _ctrl2.x);
        CGFloat minY = MIN(MIN(MIN([self startPoint].y, _curveTo.y), _ctrl1.y), _ctrl2.y);
        CGFloat maxX = MAX(MAX(MAX([self startPoint].x, _curveTo.x), _ctrl1.x), _ctrl2.x);
        CGFloat maxY = MAX(MAX(MAX([self startPoint].y, _curveTo.y), _ctrl1.y), _ctrl2.y);
        _boundsCache = CGRectMake(minX, minY, maxX - minX, maxY - minY);
        _boundsCache = CGRectInset(_boundsCache, -[self width], -[self width]);
    }
    return _boundsCache;
}

- (UIBezierPath *)borderPath
{
    if (!_borderPath) {
        // calculate curved border path
        MMVector *startVector = [MMVector vectorWithPoint:[self startPoint] andPoint:[self ctrl1]];
        CGFloat startDist = [startVector magnitude];
        MMVector *startOffsetVector = [[startVector perpendicular] normal];

        MMVector *endVector = [MMVector vectorWithPoint:[self endPoint] andPoint:[self ctrl2]];
        CGFloat endDist = [endVector magnitude];
        MMVector *endOffsetVector = [[endVector perpendicular] normal];

        CGPoint leftStart = [startOffsetVector pointFromPoint:[self startPoint] distance:[[self previousElement] width]];
        CGPoint rightStart = [startOffsetVector pointFromPoint:[self startPoint] distance:-[[self previousElement] width]];
        CGPoint leftEnd = [endOffsetVector pointFromPoint:[self endPoint] distance:-[self width]];
        CGPoint rightEnd = [endOffsetVector pointFromPoint:[self endPoint] distance:[self width]];

        // build up the final path

        CGPoint ctrl1;
        CGPoint ctrl2;

        UIBezierPath *stroke = [UIBezierPath bezierPath];
        [stroke moveToPoint:rightStart];

        ctrl1 = [[startVector normal] pointFromPoint:rightStart distance:startDist];
        ctrl2 = [[endVector normal] pointFromPoint:rightEnd distance:endDist];

        [stroke addCurveToPoint:rightEnd controlPoint1:ctrl1 controlPoint2:ctrl2];
        [stroke addLineToPoint:leftEnd];

        ctrl1 = [[endVector normal] pointFromPoint:leftEnd distance:endDist];
        ctrl2 = [[startVector normal] pointFromPoint:leftStart distance:startDist];

        [stroke addCurveToPoint:leftStart controlPoint1:ctrl1 controlPoint2:ctrl2];
        [stroke closePath];

        CGRect endOval = CGRectInset(CGRectMake([self endPoint].x, [self endPoint].y, 0, 0), -[self width], -[self width]);
        [stroke appendPath:[UIBezierPath bezierPathWithOvalInRect:endOval]];

        _borderPath = stroke;
    }

    return _borderPath;
}

/**
 * generate a vertex buffer array for all of the points
 * along this curve for the input scale.
 *
 * this method will cache the array for a single scale. if
 * a new scale is sent in later, then the cache will be rebuilt
 * for the new scale.
 */
- (UIBezierPath *)interpolatePath
{
    CGFloat const StepSize = 2;

    // since kBrushStepSize doesn't exactly divide into our segment length,
    // let's find a step size that /does/ exactly divide into our segment length
    // that's very very close to our idealStepSize of kBrushStepSize
    //
    // this'll help make the segment join its neighboring segments
    // without any artifacts of the start/end double drawing
    CGFloat realLength = [self lengthOfElement];

    NSInteger numberOfVertices = MAX(1, realLength / StepSize);

    //
    // now setup what we need to calculate the changes in width
    // along the stroke
    CGFloat prevWidth = [[self previousElement] width];
    CGFloat widthDiff = self.width - prevWidth;


    // setup a simple point array to represent our
    // bezier. this'll be what we use to subdivide
    // later on
    CGPoint rightBez[4], leftBez[4];
    CGPoint bez[4];
    bez[0] = [self startPoint];
    bez[1] = _ctrl1;
    bez[2] = _ctrl2;
    bez[3] = _curveTo;

    // track if we're the first element in a stroke. we know this
    // if we follow a moveTo. This way we know if we should
    // include the first dot in the stroke.
    BOOL isFirstElementInStroke = [self followsMoveTo];

    if (!_subBezierlengthCache) {
        _subBezierlengthCache = calloc(sizeof(CGFloat), 1000);
    }

    //
    // calculate points along the curve that are realStepSize
    // length along the curve. since this is fairly intensive for
    // the CPU, we'll cache the results
    for (int step = 0; step < numberOfVertices; step += 1) {
        // 0 <= t < 1 representing where we are in the stroke element
        CGFloat t = (CGFloat)step / (CGFloat)numberOfVertices;

        // current width
        CGFloat stepWidth = prevWidth + widthDiff * t;
        // ensure min width for dots
        if (stepWidth < kAbsoluteMinWidth)
            stepWidth = kAbsoluteMinWidth;

        // calculate the point that is realStepSize distance
        // along the curve * which step we're on
        //
        // if we're the first non-move to element on a line, then we should also
        // have the dot at the beginning of our element. otherwise, we should only
        // add an element after kBrushStepSize (including whatever distance was
        // leftover)
        CGFloat distToDot = StepSize * step + (isFirstElementInStroke ? 0 : StepSize);
        subdivideBezierAtLength(bez, leftBez, rightBez, distToDot, .1, _subBezierlengthCache);

        /// TODO: interpolate the width along the curve
        //        CGPoint point = rightBez[0];
        //        DebugLog(@"point along curve: %@", [NSValue valueWithCGPoint:point]);
    }

    return nil;
}

/**
 * helpful description when debugging
 */
- (NSString *)description
{
    if (CGPointEqualToPoint([self startPoint], _ctrl1) && CGPointEqualToPoint(_curveTo, _ctrl2)) {
        return [NSString stringWithFormat:@"[Line from: %f,%f  to: %f,%f]", [self startPoint].x, [self startPoint].y, _curveTo.x, _curveTo.y];
    } else {
        return [NSString stringWithFormat:@"[Curve from: %f,%f  to: %f,%f]", [self startPoint].x, [self startPoint].y, _curveTo.x, _curveTo.y];
    }
}

- (void)dealloc
{
    if (_subBezierlengthCache) {
        free(_subBezierlengthCache);
        _subBezierlengthCache = nil;
    }
}

#pragma mark - Events

- (void)updateWithEvent:(MMTouchStreamEvent *)event width:(CGFloat)width
{
    [super updateWithEvent:event width:width];

    if ([[[self events] firstObject] expectsLocationUpdate]) {
        _ctrl2 = _curveTo;
        _curveTo = [event location];
    }
}

- (void)clearPathCaches
{
    _borderPath = nil;
}

#pragma mark - Helper
/**
 * these bezier functions are licensed and used with permission from http://apptree.net/drawkit.htm
 */

/**
 * will divide a bezier curve into two curves at time t
 * 0 <= t <= 1.0
 *
 * these two curves will exactly match the former single curve
 */
static inline void subdivideBezierAtT(const CGPoint bez[4], CGPoint bez1[4], CGPoint bez2[4], CGFloat t)
{
    CGPoint q;
    CGFloat mt = 1 - t;

    bez1[0].x = bez[0].x;
    bez1[0].y = bez[0].y;
    bez2[3].x = bez[3].x;
    bez2[3].y = bez[3].y;

    q.x = mt * bez[1].x + t * bez[2].x;
    q.y = mt * bez[1].y + t * bez[2].y;
    bez1[1].x = mt * bez[0].x + t * bez[1].x;
    bez1[1].y = mt * bez[0].y + t * bez[1].y;
    bez2[2].x = mt * bez[2].x + t * bez[3].x;
    bez2[2].y = mt * bez[2].y + t * bez[3].y;

    bez1[2].x = mt * bez1[1].x + t * q.x;
    bez1[2].y = mt * bez1[1].y + t * q.y;
    bez2[1].x = mt * q.x + t * bez2[2].x;
    bez2[1].y = mt * q.y + t * bez2[2].y;

    bez1[3].x = bez2[0].x = mt * bez1[2].x + t * bez2[1].x;
    bez1[3].y = bez2[0].y = mt * bez1[2].y + t * bez2[1].y;
}

/**
 * divide the input curve at its halfway point
 */
static inline void subdivideBezier(const CGPoint bez[4], CGPoint bez1[4], CGPoint bez2[4])
{
    subdivideBezierAtT(bez, bez1, bez2, .5);
}

/**
 * calculates the distance between two points
 */
static inline CGFloat distanceBetween(CGPoint a, CGPoint b)
{
    return hypotf(a.x - b.x, a.y - b.y);
}

/**
 * estimates the length along the curve of the
 * input bezier within the input acceptableError
 */
CGFloat lengthOfBezier(const CGPoint bez[4], CGFloat acceptableError)
{
    CGFloat polyLen = 0.0;
    CGFloat chordLen = distanceBetween(bez[0], bez[3]);
    CGFloat retLen, errLen;
    NSUInteger n;

    for (n = 0; n < 3; ++n)
        polyLen += distanceBetween(bez[n], bez[n + 1]);

    errLen = polyLen - chordLen;

    if (errLen > acceptableError) {
        CGPoint left[4], right[4];
        subdivideBezier(bez, left, right);
        retLen = (lengthOfBezier(left, acceptableError) + lengthOfBezier(right, acceptableError));
    } else {
        retLen = 0.5 * (polyLen + chordLen);
    }

    return retLen;
}

/**
 * will split the input bezier curve at the input length
 * within a given margin of error
 *
 * the two curves will exactly match the original curve
 */
static CGFloat subdivideBezierAtLength(const CGPoint bez[4],
                                       CGPoint bez1[4],
                                       CGPoint bez2[4],
                                       CGFloat length,
                                       CGFloat acceptableError,
                                       CGFloat *subBezierlengthCache)
{
    CGFloat top = 1.0, bottom = 0.0;
    CGFloat t, prevT;

    prevT = t = 0.5;
    for (;;) {
        CGFloat len1;

        subdivideBezierAtT(bez, bez1, bez2, t);

        int lengthCacheIndex = (int)floorf(t * 1000);
        len1 = subBezierlengthCache[lengthCacheIndex];
        if (!len1) {
            len1 = lengthOfBezier(bez1, 0.5 * acceptableError);
            subBezierlengthCache[lengthCacheIndex] = len1;
        }

        if (fabs(length - len1) < acceptableError) {
            return len1;
        }

        if (length > len1) {
            bottom = t;
            t = 0.5 * (t + top);
        } else if (length < len1) {
            top = t;
            t = 0.5 * (bottom + t);
        }

        if (t == prevT) {
            subBezierlengthCache[lengthCacheIndex] = len1;
            return len1;
        }

        prevT = t;
    }
}

- (UIBezierPath *)bezierPathSegment
{
    UIBezierPath *strokePath = [UIBezierPath bezierPath];
    [strokePath moveToPoint:self.startPoint];
    [strokePath addCurveToPoint:self.endPoint controlPoint1:self.ctrl1 controlPoint2:self.ctrl2];
    return strokePath;
}


#pragma mark - hashing and equality

- (NSUInteger)hash
{
    return _hashCache;
}

- (BOOL)isEqual:(id)object
{
    return self == object || [self hash] == [object hash];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        _hashCache = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"hashCache"] unsignedIntegerValue];
        _curveTo = [coder decodeCGPointForKey:@"curveTo"];
        _ctrl1 = [coder decodeCGPointForKey:@"ctrl1"];
        _ctrl2 = [coder decodeCGPointForKey:@"ctrl2"];
        _length = [coder decodeDoubleForKey:@"length"];
        _borderPath = [coder decodeObjectOfClass:[UIBezierPath class] forKey:@"borderPath"];
        _boundsCache = [coder decodeCGRectForKey:@"boundsCache"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:@(_hashCache) forKey:@"hashCache"];
    [coder encodeCGPoint:_curveTo forKey:@"curveTo"];
    [coder encodeCGPoint:_ctrl1 forKey:@"ctrl1"];
    [coder encodeCGPoint:_ctrl2 forKey:@"ctrl2"];
    [coder encodeDouble:_length forKey:@"length"];
    [coder encodeObject:_borderPath forKey:@"borderPath"];
    [coder encodeCGRect:_boundsCache forKey:@"boundsCache"];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    MMCurveToPathElement *ret = [super copyWithZone:zone];

    ret->_hashCache = _hashCache;
    ret->_curveTo = _curveTo;
    ret->_ctrl1 = _ctrl1;
    ret->_ctrl2 = _ctrl2;
    ret->_length = _length;
    ret->_borderPath = _borderPath;
    ret->_boundsCache = _boundsCache;

    return ret;
}

@end
