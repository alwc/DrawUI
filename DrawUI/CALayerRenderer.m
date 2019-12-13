//
//  CALayerRenderer.m
//  DrawUI
//
//  Created by Adam Wulf on 11/12/19.
//  Copyright © 2019 Milestone Made. All rights reserved.
//

#import "CALayerRenderer.h"
#import "MMAbstractBezierPathElement.h"
#import "CAEraserLayer.h"
#import "CAPencilLayer.h"

@interface CALayerRenderer () <CALayerDelegate>

@end

@implementation CALayerRenderer {
    NSMutableDictionary<NSString *, CALayer *> *_strokeLayers;
    NSUInteger _lastRenderedVersion;
    CALayer *_canvasLayer;
}

@synthesize dynamicWidth;

- (instancetype)init
{
    if (self = [super init]) {
        _strokeLayers = [NSMutableDictionary dictionary];
        _lastRenderedVersion = 0;
        _canvasLayer = [CAPencilLayer layer];
        [_canvasLayer setDelegate:self];
    }
    return self;
}

#pragma mark - Render

- (__kindof CALayer *)layerForStroke:(NSString *)strokeId isEraser:(BOOL)eraser
{
    CALayer *layer = [_strokeLayers objectForKey:strokeId];

    if (!layer) {
        if ([self dynamicWidth]) {
            layer = [CALayer layer];
        } else {
            layer = [CAShapeLayer layer];
        }

        layer.delegate = self;

        [_strokeLayers setObject:layer forKey:strokeId];
    }

    return layer;
}

- (void)embedPencilLayerIfNecessary
{
    if ([_canvasLayer mask]) {
        // embed the canvas in a new pencil layer
        // so that this pencil line will be drawn
        // /over/ the eraser lines
        CALayer *subCanvasLayer = _canvasLayer;
        _canvasLayer = [CAPencilLayer layer];
        [_canvasLayer setFrame:[subCanvasLayer frame]];
        [subCanvasLayer setFrame:[subCanvasLayer bounds]];

        [[subCanvasLayer superlayer] addSublayer:_canvasLayer];
        [_canvasLayer addSublayer:subCanvasLayer];
    }
}

- (void)renderStroke:(MMDrawnStroke *)stroke inView:(MMDrawView *)drawView
{
    if ([self dynamicWidth]) {
        if (![[stroke tool] color]) {
            CAEraserLayer *eraserLayer = [_canvasLayer mask];

            if (!eraserLayer) {
                eraserLayer = [CAEraserLayer layer];
                [eraserLayer setOpaque:NO];
                [eraserLayer setFillColor:[UIColor colorWithWhite:0 alpha:0]];
                [eraserLayer setLineWidth:0];
                [_canvasLayer setMask:eraserLayer];
            }

            [eraserLayer setFrame:[drawView bounds]];
            [eraserLayer setPath:[stroke borderPath] forIdentifier:[stroke identifier]];
        } else {
            [self embedPencilLayerIfNecessary];

            // get the cached layer for this stroke. this stroke layer will contain
            // all the shape layers for each of its elements
            CALayer *layer = [self layerForStroke:[stroke identifier] isEraser:[[stroke tool] color] == nil];

            for (NSInteger i = 0; i < [[stroke segments] count]; i++) {
                MMAbstractBezierPathElement *element = [[stroke segments] objectAtIndex:i];
                CAShapeLayer *segmentLayer = i < [[layer sublayers] count] ? [[layer sublayers] objectAtIndex:i] : nil;

                if (!segmentLayer) {
                    // we don't have a layer for this segment yet, so build one
                    segmentLayer = [CAShapeLayer layer];
                    segmentLayer.delegate = self;
                    segmentLayer.fillColor = [[[stroke tool] color] CGColor] ?: [[UIColor blackColor] CGColor];
                    segmentLayer.lineWidth = 0;
                    [layer addSublayer:segmentLayer];
                }

                // update the path for this segment
                segmentLayer.path = [[element borderPath] CGPath];
            }

            if (!layer.superlayer) {
                // if we haven't added this stroke to our canvas yet, then add it.
                // we can't always call this, as it might re-order strokes or move
                // them to the wrong canvas, as updates for already drawn strokes
                // may come in to the renderStroke:inView: method
                [_canvasLayer addSublayer:layer];
            }
        }
    } else if ([stroke path]) {
        if (![[stroke tool] color]) {
            CAEraserLayer *eraserLayer = [_canvasLayer mask];

            if (!eraserLayer) {
                eraserLayer = [CAEraserLayer layer];
                [eraserLayer setOpaque:NO];
                [eraserLayer setStrokeColor:[UIColor colorWithWhite:0 alpha:0]];
                [eraserLayer setLineWidth:10];
                [_canvasLayer setMask:eraserLayer];
            }

            [eraserLayer setFrame:[drawView bounds]];
            [eraserLayer setPath:[stroke path] forIdentifier:[stroke identifier]];
        } else {
            [self embedPencilLayerIfNecessary];

            CAShapeLayer *layer = [self layerForStroke:[stroke identifier] isEraser:[[stroke tool] color] == nil];

            layer.path = [[stroke path] CGPath];
            layer.strokeColor = [[[stroke tool] color] CGColor] ?: [[UIColor colorWithWhite:0 alpha:0] CGColor];
            layer.fillColor = [[UIColor clearColor] CGColor];
            layer.lineWidth = 10;

            if (!layer.superlayer) {
                [_canvasLayer addSublayer:layer];
            }
        }
    }
}

- (void)renderModel:(MMDrawModel *)drawModel inView:(MMDrawView *)drawView
{
    NSUInteger maxSoFar = _lastRenderedVersion;

    for (MMDrawnStroke *stroke in [drawModel strokes]) {
        if ([stroke version] > _lastRenderedVersion) {
            [self renderStroke:stroke inView:drawView];

            maxSoFar = MAX([stroke version], maxSoFar);
        }
    }

    if ([drawModel stroke]) {
        if ([[drawModel stroke] version] > _lastRenderedVersion) {
            [self renderStroke:[drawModel stroke] inView:drawView];

            maxSoFar = MAX([[drawModel stroke] version], maxSoFar);
        }
    }

    _lastRenderedVersion = maxSoFar;
}

#pragma mark - MMDrawViewRenderer

- (void)drawView:(MMDrawView *)drawView willUpdateModel:(MMDrawModel *)oldModel to:(MMDrawModel *)newModel
{
    if (![_canvasLayer superlayer]) {
        [[drawView layer] addSublayer:_canvasLayer];
        [[drawView layer] setActions:@{ @"sublayers": [NSNull null] }];
    }

    if (CGRectEqualToRect([_canvasLayer frame], [[drawView layer] bounds])) {
        [_canvasLayer setFrame:[[drawView layer] bounds]];
    }
}

- (void)drawView:(MMDrawView *)drawView didUpdateModel:(MMDrawModel *)drawModel
{
    [self renderModel:drawModel inView:drawView];
}

#pragma mark - CALayerDelegate

- (nullable id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    return [NSNull null];
}


@end
