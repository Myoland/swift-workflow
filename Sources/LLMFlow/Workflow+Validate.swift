//
//  Workflow+Validate.swift
//  swift-workflow
//

// MARK: WorkflowProblem

/// A problem found by ``Workflow/Config/validate()``.
public struct WorkflowProblem: Hashable, Sendable, Codable, CustomStringConvertible {
    /// A stable identifier of the check that found a problem.
    public struct Rule: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public var description: String { rawValue }

        /// A START input type that a workflow file cannot declare (the decoder accepts only String, Int, Any,
        /// `[T]` and `[String: T]` with T one of String, Int, Any, as the whole value).
        public static let typeDecl = Rule(rawValue: "lint.type-decl")
        /// Two nodes share an id.
        public static let duplicateID = Rule(rawValue: "lint.duplicate-id")
        /// No START node, more than one, or one that is not a ``StartNode``.
        public static let start = Rule(rawValue: "lint.start")
        /// No END node.
        public static let end = Rule(rawValue: "lint.end")
        /// An edge whose `from` or `to` is not the id of a node.
        public static let edge = Rule(rawValue: "lint.edge")
        /// The edges form a cycle.
        public static let cycle = Rule(rawValue: "lint.cycle")
        /// A node that no chain of edges from START reaches.
        public static let unreachable = Rule(rawValue: "lint.unreachable")
        /// An edge out of an END node: the run ends at END and never takes it.
        public static let endEdges = Rule(rawValue: "lint.end-edges")
        /// A node other than END without outgoing edges: a run that reaches it fails.
        public static let noExit = Rule(rawValue: "lint.no-exit")
        /// A node whose outgoing edges all have a condition and are not sure to include one that holds:
        /// a run where none holds fails.
        public static let deadEnd = Rule(rawValue: "lint.dead-end")
    }

    /// The check that found the problem.
    public let rule: Rule
    /// A human-readable explanation.
    public let message: String
    /// Where the problem is, in the workflow file's terms: `nodes`, `nodes[2]`, `nodes[0].inputs.query`,
    /// `edges[3]`, `edges[3].to`.
    public let path: String

    public init(rule: Rule, message: String, path: String) {
        self.rule = rule
        self.message = message
        self.path = path
    }

    public var description: String {
        "\(path): \(message) (\(rule))"
    }
}

// MARK: Validate

public extension Workflow.Config {
    /// Checks the configuration for everything that makes the engine fail or ignore part of it, without running it.
    ///
    /// The checks, in the order of the returned problems:
    /// - ``WorkflowProblem/Rule/typeDecl``: every START input type can be written in a workflow file.
    /// - ``WorkflowProblem/Rule/duplicateID``, ``WorkflowProblem/Rule/start``, ``WorkflowProblem/Rule/end``,
    ///   ``WorkflowProblem/Rule/edge``, ``WorkflowProblem/Rule/cycle``, ``WorkflowProblem/Rule/unreachable``:
    ///   unique ids, exactly one START, at least one END, edges between existing nodes, no cycle, every node
    ///   reachable from START.
    /// - Per node: ``WorkflowProblem/Rule/endEdges`` (edges out of END), ``WorkflowProblem/Rule/noExit``
    ///   (no outgoing edge) and ``WorkflowProblem/Rule/deadEnd`` (only conditional edges, none sure to hold; see
    ///   ``Condition/isExhaustive(_:)``).
    ///
    /// ``Workflow/init(config:locator:logger:)`` does not call this method; call it before running or storing a
    /// configuration.
    ///
    /// - Returns: The problems found, empty when there are none.
    func validate() -> [WorkflowProblem] {
        var problems: [WorkflowProblem] = []

        // START input types.
        for (index, node) in nodes.enumerated() {
            guard let start = node as? StartNode else { continue }
            for (key, decl) in start.inputs.sorted(by: { $0.key < $1.key }) where FlowData.TypeDecl(decl.description) != decl {
                problems.append(.init(
                    rule: .typeDecl,
                    message: "START input `\(key)` has type `\(decl)`, which a workflow file cannot declare: use String, Int, Any, [T] or [String: T] where T is String, Int or Any.",
                    path: "nodes[\(index)].inputs.\(key)"
                ))
            }
        }

        // Unique ids.
        var firstIndex: [Node.ID: Int] = [:]
        for (index, node) in nodes.enumerated() {
            if let first = firstIndex[node.id] {
                problems.append(.init(
                    rule: .duplicateID,
                    message: "Node id `\(node.id)` is already used by nodes[\(first)].",
                    path: "nodes[\(index)].id"
                ))
            } else {
                firstIndex[node.id] = index
            }
        }

        // Exactly one START, a ``StartNode`` (as ``Workflow/init(config:locator:logger:)`` requires), at least one END.
        let starts = nodes.indices.filter { nodes[$0].type == .START }
        if let first = starts.first {
            for extra in starts.dropFirst() {
                problems.append(.init(
                    rule: .start,
                    message: "Only one START node is allowed; the first one is nodes[\(first)].",
                    path: "nodes[\(extra)]"
                ))
            }
            do {
                _ = try requireStartNode()
            } catch ConstructError.typeMissMatchStartNode {
                problems.append(.init(
                    rule: .start,
                    message: "Node `\(nodes[first].id)` is marked START but is not a StartNode: the workflow cannot be built.",
                    path: "nodes[\(first)]"
                ))
            } catch {}
        } else {
            problems.append(.init(rule: .start, message: "The workflow needs a START node.", path: "nodes"))
        }
        if !nodes.contains(where: { $0 is EndNode }) {
            problems.append(.init(rule: .end, message: "The workflow needs at least one END node.", path: "nodes"))
        }

        // Edges between existing nodes.
        var adjacency: [Node.ID: [(to: Node.ID, edge: Int)]] = [:]
        for (index, edge) in edges.enumerated() {
            var valid = true
            for (field, id) in [("from", edge.from), ("to", edge.to)] where firstIndex[id] == nil {
                valid = false
                problems.append(.init(
                    rule: .edge,
                    message: "Edge \(field) `\(id)`: there is no node with this id.",
                    path: "edges[\(index)].\(field)"
                ))
            }
            if valid {
                adjacency[edge.from, default: []].append((edge.to, index))
            }
        }

        // No cycle.
        if let cycle = Self.findCycle(nodes.map(\.id), adjacency) {
            problems.append(.init(
                rule: .cycle,
                message: "The edges form a cycle: \(cycle.ids.joined(separator: " → ")).",
                path: "edges[\(cycle.edge)]"
            ))
        }

        // Everything reachable from START.
        if let start = starts.first {
            var reached: Set<Node.ID> = [nodes[start].id]
            var queue = [nodes[start].id]
            while let current = queue.popLast() {
                for next in adjacency[current] ?? [] where reached.insert(next.to).inserted {
                    queue.append(next.to)
                }
            }
            for (index, node) in nodes.enumerated() where !reached.contains(node.id) {
                problems.append(.init(
                    rule: .unreachable,
                    message: "Node `\(node.id)` cannot be reached from START.",
                    path: "nodes[\(index)]"
                ))
            }
        }

        // Where the engine stops: it ends at END, and otherwise throws when no outgoing edge's condition holds.
        for (index, node) in nodes.enumerated() {
            let outgoing = edges.indices.filter { edges[$0].from == node.id }
            if node is EndNode {
                for edge in outgoing {
                    problems.append(.init(
                        rule: .endEdges,
                        message: "Edge from END node `\(node.id)` is never taken: the run ends at END.",
                        path: "edges[\(edge)]"
                    ))
                }
            } else if outgoing.isEmpty {
                problems.append(.init(
                    rule: .noExit,
                    message: "Node `\(node.id)` has no outgoing edge: a run that reaches it fails. Add an edge to the next node or to END.",
                    path: "nodes[\(index)]"
                ))
            } else if !Condition.isExhaustive(outgoing.map { edges[$0].condition }) {
                problems.append(.init(
                    rule: .deadEnd,
                    message: "Every outgoing edge of node `\(node.id)` has a condition, and none is sure to hold: a run where none holds fails. Add an edge without a condition after them.",
                    path: "nodes[\(index)]"
                ))
            }
        }

        return problems
    }
}

private extension Workflow.Config {
    /// A cycle as node ids (first == last) and the index of the edge that closes it, or `nil`.
    static func findCycle(
        _ ids: [Node.ID],
        _ adjacency: [Node.ID: [(to: Node.ID, edge: Int)]]
    ) -> (ids: [Node.ID], edge: Int)? {
        enum Mark { case visiting, done }
        var marks: [Node.ID: Mark] = [:]
        var stack: [Node.ID] = []

        func visit(_ id: Node.ID) -> (ids: [Node.ID], edge: Int)? {
            marks[id] = .visiting
            stack.append(id)
            for next in adjacency[id] ?? [] {
                switch marks[next.to] {
                case .visiting:
                    let start = stack.lastIndex(of: next.to) ?? 0
                    return (Array(stack[start...]) + [next.to], next.edge)
                case .done:
                    continue
                case nil:
                    if let found = visit(next.to) { return found }
                }
            }
            stack.removeLast()
            marks[id] = .done
            return nil
        }

        for id in ids where marks[id] == nil {
            if let found = visit(id) { return found }
        }
        return nil
    }
}

// MARK: Run Paths

public extension Workflow.Config {
    /// The edges out of a node that the engine may evaluate, in order.
    struct EvaluatedEdges: Hashable, Sendable {
        /// Indices into ``Workflow/Config/edges``, in their order there.
        public let indices: [Int]
        /// Whether the last of ``indices`` is sure to be taken when the engine gets to it: it has no condition,
        /// its condition always holds, or it is the `not` of an earlier one (or the other way round).
        /// When `false`, the run fails if none of the conditions holds.
        public let isExhaustive: Bool

        public init(indices: [Int], isExhaustive: Bool) {
            self.indices = indices
            self.isExhaustive = isExhaustive
        }
    }

    /// A sequence of nodes the engine can run, from START.
    struct RunPath: Hashable, Sendable {
        /// Indices into ``Workflow/Config/nodes``; the first is START.
        public let nodeIndices: [Int]
        /// Indices into ``Workflow/Config/edges``: `edgeIndices[k]` leads from `nodeIndices[k]` to `nodeIndices[k + 1]`.
        public let edgeIndices: [Int]

        public init(nodeIndices: [Int], edgeIndices: [Int]) {
            self.nodeIndices = nodeIndices
            self.edgeIndices = edgeIndices
        }
    }

    /// The result of ``Workflow/Config/runPaths(context:limit:)``.
    struct RunPaths: Hashable, Sendable {
        /// The paths, depth first in edge order.
        public let paths: [RunPath]
        /// `false` when there are more paths than the limit; ``paths`` then holds the first ones.
        public let isComplete: Bool

        public init(paths: [RunPath], isComplete: Bool) {
            self.paths = paths
            self.isComplete = isComplete
        }
    }

    /// The default `limit` of ``runPaths(context:limit:)``.
    static let defaultRunPathLimit = 256

    /// The edges out of `nodeID` that the engine may evaluate.
    ///
    /// The engine takes the first outgoing edge, in ``edges`` order, whose condition holds (an edge without a
    /// condition always holds). Edges after one that is sure to be taken are never evaluated. A later edge whose
    /// condition is the same as an earlier one's is evaluated but never taken.
    /// The engine also stops at END without evaluating its edges; this method does not look at the node's type.
    func evaluatedEdges(from nodeID: Node.ID) -> EvaluatedEdges {
        var indices: [Int] = []
        var earlier: [Condition] = []
        for (index, edge) in edges.enumerated() where edge.from == nodeID {
            indices.append(index)
            guard let condition = edge.condition else {
                return .init(indices: indices, isExhaustive: true)
            }
            if condition.constantValue == true || earlier.contains(where: { $0 == .not(condition) || condition == .not($0) }) {
                return .init(indices: indices, isExhaustive: true)
            }
            earlier.append(condition)
        }
        return .init(indices: indices, isExhaustive: false)
    }

    /// The paths the engine can take from START, at most `limit` of them, for dry runs that run each path in its
    /// own context.
    ///
    /// After each node, the edges of ``evaluatedEdges(from:)`` are considered in order, as the engine evaluates them.
    /// A condition's result is known when
    /// - it does not read the context (``Condition/constantValue``),
    /// - the same condition (or its `not`) was already evaluated on this path and no node run since writes what it
    ///   reads: two splits on the same input give two paths, not four, and a later edge with the same condition as an
    ///   earlier one at the same node is never taken,
    /// - or every variable it reads is in `context` and no node other than START writes it.
    ///
    /// A known result is followed exactly: the edge is taken (and the later edges are not), skipped, or, when the
    /// evaluation throws (``ContextStorePath/IndexOutOfRangeError``), the path ends at that node. When the result is
    /// unknown (for example a condition on an LLM answer), both are possible: the path branches into one that takes
    /// the edge and one that goes on with the next edge. A path ends at END (the engine stops there), at a node where
    /// the engine cannot take any edge, or before an edge to a missing node or back to a node already on the path
    /// (``validate()`` reports those).
    ///
    /// The result is exact when every condition is known. Branches on unknown values are a conservative
    /// over-approximation: every path the engine can take is listed, and some listed paths may be impossible at run
    /// time (for example when two different conditions read the same unknown value).
    ///
    /// - Parameters:
    ///   - context: Values known before the run, as the context store holds them after START, for example the
    ///     caller's sample inputs: `["workflow": ["inputs": ["query": "a"]]]`. Values that a node writes
    ///     (`<node id>.output`, `workflow.output.<key>`) are not taken from it. `nil`: no value is known.
    ///   - limit: The maximum number of paths; the number of paths grows exponentially with unknown branches.
    /// - Returns: The paths, depth first in edge order. `isComplete == false` means the enumeration stopped at
    ///   `limit` and more paths exist.
    func runPaths(context: [String: AnySendable]? = nil, limit: Int = defaultRunPathLimit) -> RunPaths {
        var nodeIndex: [Node.ID: Int] = [:]
        for (index, node) in nodes.enumerated() where nodeIndex[node.id] == nil {
            nodeIndex[node.id] = index
        }
        guard let start = nodes.firstIndex(where: { $0.type == .START }) else {
            return .init(paths: [], isComplete: true)
        }

        var paths: [RunPath] = []
        var isComplete = true

        func overlap(_ variables: [ContextStorePath], _ writes: [[String]]) -> Bool {
            variables.contains { variable in
                let keys = variable.keys.map(\.strValue)
                return writes.contains { $0.starts(with: keys) || keys.starts(with: $0) }
            }
        }

        /// Whether a node on `path` after `position` may write a value that `variables` read.
        func mayChange(_ variables: [ContextStorePath], after position: Int, on path: [Int]) -> Bool {
            path.indices.contains { later in
                guard later > position else { return false }
                guard let writes = Self.writtenKeyPaths(of: nodes[path[later]]) else { return true }
                return overlap(variables, writes)
            }
        }

        /// What any node but START may write; `nil` when unknown. `context` holds none of it: a node writes it later.
        let writtenByNodes: [[String]]? = nodes.filter { !($0 is StartNode) }.reduce([]) { writes, node in
            guard let writes, let more = Self.writtenKeyPaths(of: node) else { return nil }
            return writes + more
        }

        func outcome(of condition: Condition, on path: [Int], facts: [ConditionFact]) -> ConditionOutcome {
            if let value = condition.constantValue {
                return value ? .holds : .fails
            }
            let variables = condition.variables
            for fact in facts.reversed() where !mayChange(variables, after: fact.position, on: path) {
                if fact.condition == condition {
                    return fact.value ? .holds : .fails
                }
                if fact.condition == .not(condition) || condition == .not(fact.condition) {
                    return fact.value ? .fails : .holds
                }
            }
            if let context, let writtenByNodes, !overlap(variables, writtenByNodes) {
                // A lookup that throws reads a known list out of range: the evaluation below decides.
                let known = variables.allSatisfy { variable in
                    do { return try variable.lookup(in: context) != nil } catch { return true }
                }
                guard known else { return .unknown }
                do {
                    return try condition.evaluate(context) ? .holds : .fails
                } catch {
                    return .throws
                }
            }
            return .unknown
        }

        func walk(_ path: RunPath, _ facts: [ConditionFact]) {
            guard isComplete, let last = path.nodeIndices.last else { return }
            let node = nodes[last]
            let position = path.nodeIndices.count - 1

            var taken: [(edge: Int, facts: [ConditionFact])] = []
            if !(node is EndNode) {
                var facts = facts
                scan: for edge in evaluatedEdges(from: node.id).indices {
                    guard let condition = edges[edge].condition else {
                        taken.append((edge, facts))
                        break scan
                    }
                    switch outcome(of: condition, on: path.nodeIndices, facts: facts) {
                    case .holds:
                        taken.append((edge, facts))
                        break scan
                    case .fails:
                        continue
                    case .throws:
                        break scan
                    case .unknown:
                        taken.append((edge, facts + [ConditionFact(condition: condition, value: true, position: position)]))
                        facts.append(ConditionFact(condition: condition, value: false, position: position))
                    }
                }
            }

            let next = taken.compactMap { edge, facts -> (node: Int, edge: Int, facts: [ConditionFact])? in
                guard let target = nodeIndex[edges[edge].to], !path.nodeIndices.contains(target) else { return nil }
                return (target, edge, facts)
            }
            guard !next.isEmpty else {
                if paths.count < limit {
                    paths.append(path)
                } else {
                    isComplete = false
                }
                return
            }
            for (target, edge, facts) in next {
                walk(RunPath(nodeIndices: path.nodeIndices + [target], edgeIndices: path.edgeIndices + [edge]), facts)
            }
        }

        walk(RunPath(nodeIndices: [start], edgeIndices: []), [])
        return .init(paths: paths, isComplete: isComplete)
    }
}

/// What ``Workflow/Config/runPaths(context:limit:)`` knows of an edge condition.
private enum ConditionOutcome {
    case holds, fails, `throws`, unknown
}

/// A condition the engine evaluated on a path, with its result, after the node at `position` on the path.
private struct ConditionFact {
    let condition: Condition
    let value: Bool
    let position: Int
}

private extension Workflow.Config {
    /// The context key paths a node's `update` writes, or `nil` when unknown (a node type of another library).
    static func writtenKeyPaths(of node: any Node) -> [[String]]? {
        switch node {
        case is StartNode:
            [ContextStoreKey.WorkflowInputsKeyPath]
        case is EndNode:
            []
        case let node as LLMNode:
            [node.resultKeyPaths] + (node.outputKeyPaths.map { [$0] } ?? [])
        case let node as TemplateNode:
            [node.resultKeyPaths]
        default:
            nil
        }
    }
}
