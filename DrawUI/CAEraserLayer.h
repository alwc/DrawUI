//
//  CAEraserLayer.h
//  DrawUI
//
//  Created by Adam Wulf on 11/30/19.
//  Copyright © 2019 Milestone Made. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CAEraserLayer : CALayer

@property(nonatomic) UIColor *fillColor;
@property(nonatomic) UIColor *strokeColor;
@property(nonatomic) CGFloat lineWidth;

- (void)setPath:(UIBezierPath *)path forIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END