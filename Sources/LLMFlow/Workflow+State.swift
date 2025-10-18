//
//  Workflow+State.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/14.
//

import LazyKit
import SynchronizationKit
import Tracing

// MARK: Workflow + Run

public extension Workflow {
    /// Runs the workflow with the given inputs.
    ///
    /// This method is the primary entry point for executing a workflow. It initializes the execution context
    /// with the provided inputs and returns an asynchronous sequence of state updates.
    ///
    /// - Parameters:
    ///   - inputs: A dictionary of input data for the workflow, keyed by the input names defined in the ``StartNode``.
    ///   - context: An optional initial ``Context`` for the workflow. If not provided, a new empty context is created.
    /// - Throws: An error if the workflow is misconfigured (e.g., cannot find the start node).
    /// - Returns: A ``RunningUpdates`` object, which is an `AsyncSequence` that emits ``PipeState`` updates as the workflow progresses.
    func run(inputs: [String: FlowData], context: Context = .init(), serviceContext: ServiceContext = .current ?? .topLevel) throws -> RunningUpdates {
        context.payload.withLock { $0 = .block(inputs) }
        return try RunningUpdates(workflow: self, startNode: requireStartNode(), inputs: inputs, context: context, serviceContext: serviceContext)
    }
}

public extension Workflow {
    /// Represents the state of a node's execution within a running workflow.
    enum PipeStateType: Hashable, Sendable {
        /// The workflow is starting at the ``StartNode``.
        case start
        /// A node is actively streaming its output. A ``PipeState`` with this type will be emitted for each chunk of the stream.
        case generating
        /// A node has begun a streaming operation.
        case startGenerating
        /// A node has completed a streaming operation.
        case finishGenerating
        /// A node has finished its execution (for non-streaming nodes) and the workflow is transitioning to the next node.
        case running
        /// The workflow has reached an `EndNode` and has completed.
        case end
    }

    /// A snapshot of the workflow's state at a specific point in its execution.
    ///
    /// The ``RunningUpdates`` async sequence emits `PipeState` instances, allowing you to observe the
    /// progress of a workflow, including which node is running and what data is being produced.
    struct PipeState {
        /// The type of state this update represents.
        public let type: PipeStateType
        /// The node that this state update pertains to.
        public let node: any Node
        /// A reference to the workflow's current ``Context``.
        public let context: Context
        /// The value associated with this state, typically a chunk of data for `.generating` states.
        public let value: Context.Value?
    }
}

extension Workflow.PipeStateType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .start:
            "start"
        case .generating:
            "generating"
        case .startGenerating:
            "generating"
        case .finishGenerating:
            "finishGenerating"
        case .running:
            "running"
        case .end:
            "end"
        }
    }
}

public extension Workflow.PipeState {
    /// The most recent output from the node, available in the context.
    var payload: NodeOutput? {
        context.payload.withLock { $0 }
    }
}

public extension Workflow {
    /// An `AsyncSequence` that provides real-time updates on the state of a running ``Workflow``.
    ///
    /// You can iterate over this sequence to receive ``PipeState`` objects as the workflow executes,
    /// allowing for observation of the flow's progress, streaming of LLM outputs, and access to intermediate data.
    ///
    /// ```swift
    /// let updates = try workflow.run(inputs: ["query": "Tell me a joke."])
    /// for try await state in updates {
    ///     print("Node '\(state.node.id)' is now in state '\(state.type)'.")
    ///     if state.type == .generating, let chunk = state.value {
    ///         print("Received chunk: \(chunk)")
    ///     }
    /// }
    /// ```
    struct RunningUpdates: AsyncSequence, Sendable {
        public typealias Element = PipeState
        public typealias AsyncIterator = Iterator

        /// The ``Workflow`` instance being executed.
        public let workflow: Workflow
        /// The ``StartNode`` where the execution begins.
        public let startNode: StartNode
        /// The initial inputs provided to the workflow.
        public let inputs: [String: FlowData]
        /// The shared ``Context`` for this workflow run.
        public let context: Context

        public let serviceContext: ServiceContext

        public init(
            workflow: Workflow,
            startNode: StartNode,
            inputs: [String: FlowData],
            context: Context,
            serviceContext: ServiceContext = .current ?? .topLevel
        ) {
            self.workflow = workflow
            self.startNode = startNode
            self.inputs = inputs
            self.context = context
            self.serviceContext = serviceContext
        }

        /// Creates an asynchronous iterator to begin the workflow execution.
        public func makeAsyncIterator() -> Iterator {
            Iterator(delegate: workflow,
                     executor: Executor(locator: workflow.locator, context: context, serviceContext: serviceContext, logger: workflow.logger),
                     node: startNode)
        }
    }
}

/// A protocol that provides the ``Workflow/RunningUpdates/Iterator`` with access to the workflow's structure.
///
/// This abstraction decouples the iterator's execution logic from the concrete `Workflow` type,
/// aiding in testability and modularity.
public protocol WorkflowControl: Sendable {
    /// Retrieves the outgoing edges for a given node.
    /// - Parameter id: The ID of the source node.
    /// - Returns: An array of ``Workflow/Edge``s.
    func edges(from id: Node.ID) -> [Workflow.Edge]

    /// Retrieves a node by its ID.
    /// - Parameter id: The ID of the node to retrieve.
    /// - Returns: The ``RunnableNode`` if found, otherwise `nil`.
    func node(id: Node.ID) -> (any RunnableNode)?
}

extension Workflow: WorkflowControl {
    public func edges(from id: Node.ID) -> [Workflow.Edge] {
        flows[id] ?? []
    }

    public func node(id: String) -> (any RunnableNode)? {
        nodes[id]
    }
}

/// A type alias for a type that conforms to both ``Runnable`` and ``Node``.
public typealias RunnableNode = Node & Runnable

public extension Workflow.RunningUpdates {
    enum RunningState: Sendable {
        case initial(StartNode)
        case modifying
        case running(current: any RunnableNode, previous: (any RunnableNode)?)
        case generating(current: any RunnableNode, AnyAsyncSequence<Context.Value>.AsyncIterator)
        case end

        public var isModifying: Bool {
            guard case .modifying = self else {
                return false
            }
            return true
        }

        public var isEnd: Bool {
            guard case .end = self else {
                return false
            }
            return true
        }
    }
}

extension Workflow.RunningUpdates.RunningState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .initial(_):
            "initial"
        case .modifying:
            "modifying"
        case .running(_, _):
            "running"
        case .generating(_, _):
            "generating"
        case .end:
            "end"
        }
    }
}

public extension Workflow.RunningUpdates {
    /// The asynchronous iterator that drives the execution of a ``Workflow``.
    ///
    /// This iterator manages the state machine of the workflow, advancing from one node to the next,
    /// handling node execution, and emitting ``PipeState`` updates.
    struct Iterator: AsyncIteratorProtocol, Sendable {
        typealias Err = RuntimeError

        private let delegate: any WorkflowControl
        /// The executor responsible for running the logic of each node.
        public let executor: Executor

        private let lockedState: LazyLockedValue<RunningState>

        /// Initializes the iterator for a workflow execution.
        public init(delegate: any WorkflowControl, executor: Executor, node: StartNode) {
            self.delegate = delegate
            self.executor = executor
            self.lockedState = .init(.initial(node))
        }

        /// Asynchronously advances the workflow to the next state and returns it.
        ///
        /// This method contains the core logic of the workflow's state machine. It is called repeatedly
        /// by the `for-try-await` loop on a ``RunningUpdates`` sequence.
        ///
        /// - Returns: The next ``Workflow/PipeState`` in the execution, or `nil` if the workflow has completed.
        /// - Throws: A ``RuntimeError`` if an issue occurs during execution, such as a node not being found or an edge condition failing.
        public mutating func next() async throws -> Workflow.PipeState? {
            let state: RunningState = lockedState.withLock { state in
                let old = state
                switch state {
                case .end:
                    break
                default:
                    state = .modifying
                }
                return old
            }
            assert(state.isModifying == false) // Make sure next() is not re-enter.

            let cxtRef = executor.context
            switch state {
            case .end:
                return nil

            case .initial(let node):
                self.state = .running(current: node, previous: nil)
                return Workflow.PipeState(type: .start, node: node, context: cxtRef, value: nil)

            case .running(current: let node, previous: _) where node is EndNode:
                let output = try await node.run(executor: executor)
                cxtRef.payload.withLock { $0 = output }

                if let value = output?.value {
                    try node.update(cxtRef, value: value)
                    executor.logger.info("[*] Node(\(node.id)). Update Success. Value: \(String(describing: value))")
                }

                self.state = .end
                return Workflow.PipeState(type: .end, node: node, context: cxtRef, value: "TODO: Object Used for summrize")

            case .running(current: let node, previous: _):
                let output = try await node.run(executor: executor)
                cxtRef.payload.withLock { $0 = output }

                if let stream = output?.stream {
                    let iterator = stream.makeAsyncIterator()
                    self.state = .generating(current: node, iterator)
                    return Workflow.PipeState(type: .startGenerating, node: node, context: cxtRef, value: nil)
                }

                if let value = output?.value {
                    try node.update(cxtRef, value: value)
                    executor.logger.info("[*] Node(\(node.id)). Update Success. Value: \(String(describing: value))")
                }

                let next = try requireNextNode(from: node.id, context: cxtRef.filter(keys: nil))

                self.state = .running(current: next, previous: node)
                return Workflow.PipeState(type: .running, node: node, context: cxtRef, value: nil)

            case .generating(let node, var iterator):
                if let elem = try await iterator.next() {
                    self.state = .generating(current: node, iterator)
                    return Workflow.PipeState(type: .generating, node: node, context: cxtRef, value: elem)
                }

                // iterator finished
                let value = try await node.wait(cxtRef)
                try node.update(cxtRef, value: value)
                executor.logger.info("[*] Node(\(node.id)). Update Success. Value: \(String(describing: value))")

                let next = try requireNextNode(from: node.id, context: cxtRef.filter(keys: nil))

                self.state = .running(current: next, previous: node)
                return Workflow.PipeState(type: .finishGenerating, node: node, context: cxtRef, value: nil)

            case .modifying:
                unreachable()
            }
        }

        /// Determines the next node to execute based on the outgoing edges of the current node.
        ///
        /// It evaluates the ``Condition`` on each edge and selects the first one that passes.
        ///
        /// - Parameters:
        ///   - nodeID: The ID of the current node.
        ///   - context: The current workflow context, used for evaluating conditions.
        /// - Throws: ``RuntimeError/CanNotMatchAnEdge`` if no outgoing edge's condition is met.
        /// - Throws: ``RuntimeError/NextNodeNotFound`` if the target node of the matched edge does not exist.
        /// - Returns: The next ``RunnableNode`` to be executed.
        public func requireNextNode(from nodeID: Node.ID, context: [Context.Key: Context.Value]) throws -> any RunnableNode {
            let edges = delegate.edges(from: nodeID)
            let edge = edges.first { $0.condition?.eval(context) ?? true }

            guard let edge else { throw Err.CanNotMatchAnEdge }
            guard let next = delegate.node(id: edge.to) else { throw Err.NextNodeNotFound }

            return next
        }
    }
}

extension Workflow.RunningUpdates.Iterator {
    /// Provides thread-safe access to the internal running state of the iterator.
    var state: Workflow.RunningUpdates.RunningState {
        get {
            lockedState.withLock { $0 }
        }
        set {
            lockedState.withLock { $0 = newValue }
        }
    }
}
