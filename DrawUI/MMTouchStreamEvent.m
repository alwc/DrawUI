//
//  MMTouchStreamEvent.m
//  DrawUI
//
//  Created by Adam Wulf on 11/15/19.
//  Copyright © 2019 Milestone Made. All rights reserved.
//

#import "MMTouchStreamEvent.h"

@implementation MMTouchStreamEvent

+ (MMTouchStreamEvent *)eventWithCoalescedTouch:(UITouch *)coalescedTouch touch:(UITouch *)touch velocity:(CGFloat)velocity isUpdate:(BOOL)update isPrediction:(BOOL)prediction
{
    MMTouchStreamEvent *event = [[MMTouchStreamEvent alloc] init];

    [event setUuid:[[NSUUID UUID] UUIDString]];
    [event setCoalescedTouch:coalescedTouch];
    [event setTouch:touch];
    [event setTimestamp:[coalescedTouch timestamp]];
    [event setType:[coalescedTouch type]];
    [event setPhase:[coalescedTouch phase]];
    [event setForce:[coalescedTouch force]];
    [event setMaximumPossibleForce:[coalescedTouch maximumPossibleForce]];
    [event setAzimuth:[coalescedTouch azimuthAngleInView:[coalescedTouch view]]];
    [event setVelocity:velocity];
    [event setMajorRadius:[coalescedTouch majorRadius]];
    [event setMajorRadiusTolerance:[coalescedTouch majorRadiusTolerance]];
    [event setLocation:[coalescedTouch preciseLocationInView:[coalescedTouch view]]];
    [event setInView:[coalescedTouch view]];
    [event setEstimationUpdateIndex:[coalescedTouch estimationUpdateIndex]];
    [event setEstimatedProperties:[coalescedTouch estimatedProperties]];
    [event setEstimatedPropertiesExpectingUpdates:[coalescedTouch estimatedPropertiesExpectingUpdates]];
    [event setUpdate:update];
    [event setPrediction:prediction];

    return event;
}

- (BOOL)matchesEvent:(MMTouchStreamEvent *)otherEvent
{
    return [self touch] == [otherEvent touch];
}


@end