//
//  Trace+Kit.swift
//  swift-workflow
//
//  Created by Huanan on 2025/10/14.
//

import Tracing

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func nodeOutputWithSpan(
    _ operationName: String,
    context: @autoclosure () -> ServiceContext = .current ?? .topLevel,
    ofKind kind: SpanKind = .internal,
    function: String = #function,
    file fileID: String = #fileID,
    line: UInt = #line,
    _ operation: (any Span) async throws -> NodeOutput?
) async rethrows -> NodeOutput? {
    let span = startSpan(operationName, context: context(), ofKind: kind, function: function, file: fileID, line: line)
    
    do {
        let output = try await operation(span)
        switch output {
        case .none:
            span.end()
            return .none
        case .block(let value):
            span.end()
            return .block(value)
        case .stream(let sequence):
            let iterator = sequence.makeAsyncIterator()
            let stream = AsyncThrowingStream(unfolding: { [iterator] in
                var iterator = iterator
                if let elem = try await iterator.next() {
                    return elem
                } else {
                    span.end()
                    return nil
                }
            })
            return .stream(stream.eraseToAnyAsyncSequence())
        }
    } catch {
        span.recordError(error)
        span.end()
        throw error
    }
}
