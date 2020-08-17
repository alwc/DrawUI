//
//  Strokes.swift
//  DrawUI
//
//  Created by Adam Wulf on 8/16/20.
//

import Foundation

public class Strokes {

    public enum Delta {
        case addedStroke(stroke: Stroke)
        case updatedStroke(stroke: Stroke, updatedIndexes: IndexSet)
        case completedStroke(stroke: Stroke)

        public var rawString: String {
            switch self {
            case .addedStroke(let stroke):
                return "addedStroke(\(stroke.touchIdentifier))"
            case .updatedStroke(let stroke, let indexSet):
                return "updatedStroke(\(stroke.touchIdentifier), \(indexSet)"
            case .completedStroke(let stroke):
                return "completedStroke(\(stroke.touchIdentifier))"
            }
        }
    }

    public private(set) var strokes: [Stroke]
    public private(set) var touchToStroke: [String: Stroke]

    public init() {
        touchToStroke = [:]
        strokes = []
    }

    @discardableResult
    public func add(touchEvents: [TouchEvent]) -> [Delta] {
        var deltas: [Delta] = []
        let updatedEventsPerTouch = touchEvents.reduce([:], { (result, event) -> [String: [TouchEvent]] in
            var result = result
            if result[event.touchIdentifier] != nil {
                result[event.touchIdentifier]?.append(event)
            } else {
                result[event.touchIdentifier] = [event]
            }
            return result
        })

        for (touchIdentifier, events) in updatedEventsPerTouch {
            if let stroke = touchToStroke[touchIdentifier] {
                let updatedIndexes = stroke.add(touchEvents: events)
                deltas.append(.updatedStroke(stroke: stroke, updatedIndexes: updatedIndexes))
                if stroke.isComplete {
                    deltas.append(.completedStroke(stroke: stroke))
                }
            } else if let touchIdentifier = events.first?.touchIdentifier,
                      let stroke = Stroke(touchEvents: events) {
                touchToStroke[touchIdentifier] = stroke
                strokes.append(stroke)
                deltas.append(.addedStroke(stroke: stroke))
            }
        }

        return deltas
    }
}