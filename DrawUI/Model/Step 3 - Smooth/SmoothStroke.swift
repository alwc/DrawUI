//
//  SmoothStroke.swift
//  DrawUI
//
//  Created by Adam Wulf on 8/17/20.
//

import Foundation

public class SmoothStroke {
    // MARK: - Public Properties
    public var touchIdentifier: String {
        return stroke.touchIdentifier
    }
    public var points: [SmoothStrokePoint]

    private var stroke: OrderedTouchPoints

    init(stroke: OrderedTouchPoints) {
        self.stroke = stroke
        self.points = stroke.points.map({ SmoothStrokePoint(point: $0) })
    }

    // TODO:
    // for smoothing, perhaps have an object that can either smooth a SmoothStrokePoint array
    // or can smooth [SmoothStrokePoint] and IndexSet, returning ([SmoothStrokePoint], IndexSet).
    // then these can be chained together or even reordered
    func update(with stroke: OrderedTouchPoints, indexSet: IndexSet) -> IndexSet {
        for index in indexSet {
            if index < stroke.points.count {
                if index < points.count {
                    points[index].location = stroke.points[index].event.location
                } else if index == points.count {
                    points.append(SmoothStrokePoint(point: stroke.points[index]))
                } else {
                    assertionFailure("Attempting to modify a point that doesn't yet exist. maybe an update is out of order?")
                }
            } else {
                points.remove(at: index)
            }
        }
        return indexSet
    }
}
