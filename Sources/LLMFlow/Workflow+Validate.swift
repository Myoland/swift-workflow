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
        /// How a path ends.
        public enum Termination: Hashable, Sendable {
            /// At an END node: the run completes.
            case end
            /// The run may fail here: no outgoing edge, or none whose condition holds (`CanNotMatchAnEdge`).
            case noMatchingEdge
            /// The run may fail here: evaluating the condition of `edges[edge]` may throw (a variable that indexes a
            /// list out of range).
            case evaluationError(edge: Int)
            /// The run may fail here: `edges[edge]` may be taken and leads to a node that does not exist.
            case missingNode(edge: Int)
            /// `edges[edge]` may be taken and leads back to a node already on the path (a cycle; the path stops).
            case cycle(edge: Int)
        }

        /// Indices into ``Workflow/Config/nodes``; the first is START.
        public let nodeIndices: [Int]
        /// Indices into ``Workflow/Config/edges``: `edgeIndices[k]` leads from `nodeIndices[k]` to `nodeIndices[k + 1]`.
        public let edgeIndices: [Int]
        /// How the path ends, after its last node.
        public let termination: Termination

        public init(nodeIndices: [Int], edgeIndices: [Int], termination: Termination = .end) {
            self.nodeIndices = nodeIndices
            self.edgeIndices = edgeIndices
            self.termination = termination
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
    /// After each node, the outgoing edges are considered in ``edges`` order, and each condition sub-expression by
    /// sub-expression in the engine's order (`and` stops at the first that fails, `or` at the first that holds).
    /// A comparison's result is known when
    /// - the same comparison was already evaluated on this path and no node run since writes what it reads: two splits
    ///   on the same input give two paths, not four, and a later edge with the same condition as an earlier one at the
    ///   same node is never taken;
    /// - or the variable it reads is in `context` (or indexes a list of `context` out of range) and no node other than
    ///   START writes it.
    ///
    /// A known result is followed exactly. An unknown one (for example a comparison on an LLM answer) may hold or
    /// not, and the path branches at the edge; when its variable has a list index, its evaluation may also throw.
    ///
    /// Every way a run can go is listed, including where it stops (``RunPath/termination``): at END, or where it may
    /// fail (no edge whose condition holds, an evaluation that throws, an edge to a missing node) or loop (an edge
    /// back to a node on the path). A configuration that passes ``validate()`` can still have such paths, for example
    /// a condition that reads `workflow.inputs.items.0` of a list that may be empty.
    ///
    /// The result is exact when every comparison is known. Branches on unknown values are a conservative
    /// over-approximation: some listed paths may be impossible at run time (for example when two different
    /// comparisons read the same unknown value). Identical paths are listed once.
    ///
    /// - Parameters:
    ///   - context: Values known before the run, as the context store holds them after START, for example the
    ///     caller's sample inputs: `["workflow": ["inputs": ["query": "a"]]]`. Values that a node writes
    ///     (`<node id>.output`, `workflow.output.<key>`) are not taken from it. `nil`: no value is known.
    ///   - limit: The maximum number of paths; the number of paths grows exponentially with unknown branches.
    /// - Returns: The paths, depth first in edge order. `isComplete == false` means the enumeration stopped early:
    ///   at `limit` paths, or after a bounded amount of work (about `1000 × max(limit, 256)` evaluation steps), so
    ///   a crafted configuration cannot make it run for long. More paths may exist.
    func runPaths(context: [String: AnySendable]? = nil, limit: Int = defaultRunPathLimit) -> RunPaths {
        var nodeIndex: [Node.ID: Int] = [:]
        for (index, node) in nodes.enumerated() where nodeIndex[node.id] == nil {
            nodeIndex[node.id] = index
        }
        guard let start = nodes.firstIndex(where: { $0.type == .START }) else {
            return .init(paths: [], isComplete: true)
        }

        var paths: [RunPath] = []
        var seen: Set<RunPath> = []
        var isComplete = true

        // Bounds the work, not only the paths: condition outcomes multiply before any path is emitted.
        var steps = 0
        let maxSteps = max(limit, Self.defaultRunPathLimit) * 1_000
        func spend() -> Bool {
            steps += 1
            if steps > maxSteps { isComplete = false }
            return isComplete
        }

        func overlap(_ variable: ContextStorePath, _ writes: [[String]]) -> Bool {
            let keys = variable.keys.map(\.strValue)
            return writes.contains { $0.starts(with: keys) || keys.starts(with: $0) }
        }

        /// Whether a node on `path` after `position` may write a value that `variable` reads.
        func mayChange(_ variable: ContextStorePath, after position: Int, on path: [Int]) -> Bool {
            path.indices.contains { later in
                guard later > position else { return false }
                guard let writes = Self.writtenKeyPaths(of: nodes[path[later]]) else { return true }
                return overlap(variable, writes)
            }
        }

        /// What any node but START may write; `nil` when unknown. `context` holds none of it: a node writes it later.
        let writtenByNodes: [[String]]? = nodes.filter { !($0 is StartNode) }.reduce([]) { writes, node in
            guard let writes, let more = Self.writtenKeyPaths(of: node) else { return nil }
            return writes + more
        }

        /// The possible results of evaluating `condition` as ``Condition/evaluate(_:)`` does, each with what is known
        /// afterwards.
        func evaluate(
            _ condition: Condition, _ facts: [ComparisonFact], on path: [Int]
        ) -> [(outcome: ConditionOutcome, facts: [ComparisonFact])] {
            guard spend() else { return [] }
            switch condition {
            case .and(let conditions), .or(let conditions):
                // `and` goes on while the sub-conditions hold, `or` while they fail.
                let goOn: ConditionOutcome = if case .and = condition { .holds } else { .fails }
                var results: [(outcome: ConditionOutcome, facts: [ComparisonFact])] = []
                var pending = [facts]
                for condition in conditions {
                    var next: [[ComparisonFact]] = []
                    for facts in pending {
                        for result in evaluate(condition, facts, on: path) {
                            if result.outcome == goOn { next.append(result.facts) } else { results.append(result) }
                        }
                    }
                    pending = next
                }
                return results + pending.map { (goOn, $0) }
            case .not(let condition):
                return evaluate(condition, facts, on: path).map { result in
                    switch result.outcome {
                    case .holds: (.fails, result.facts)
                    case .fails: (.holds, result.facts)
                    case .throws: (.throws, result.facts)
                    }
                }
            case .string, .int:
                guard let variable = condition.variables.first else { return [] }
                for fact in facts.reversed() where fact.comparison == condition && !mayChange(variable, after: fact.position, on: path) {
                    return [(fact.value ? .holds : .fails, facts)]
                }
                if let context, let writtenByNodes, !overlap(variable, writtenByNodes) {
                    // Known: present, or a list of `context` indexed out of range.
                    let known: Bool
                    do {
                        known = try variable.lookup(in: context) != nil
                    } catch {
                        known = true
                    }
                    if known {
                        do {
                            return [(try condition.evaluate(context) ? .holds : .fails, facts)]
                        } catch {
                            return [(.throws, facts)]
                        }
                    }
                }
                let position = path.count - 1
                var results: [(outcome: ConditionOutcome, facts: [ComparisonFact])] = [
                    (.holds, facts + [ComparisonFact(comparison: condition, value: true, position: position)]),
                    (.fails, facts + [ComparisonFact(comparison: condition, value: false, position: position)]),
                ]
                if variable.keys.contains(where: { $0.intValue != nil }) {
                    results.append((.throws, facts))
                }
                return results
            }
        }

        func emit(_ path: RunPath) {
            guard !seen.contains(path) else { return }
            if paths.count < limit {
                paths.append(path)
                seen.insert(path)
            } else {
                isComplete = false
            }
        }

        enum Step {
            case take(edge: Int, facts: [ComparisonFact])
            case stop(RunPath.Termination)
        }

        func walk(_ nodeIndices: [Int], _ edgeIndices: [Int], _ facts: [ComparisonFact]) {
            guard spend(), let last = nodeIndices.last else { return }
            let node = nodes[last]
            guard !(node is EndNode) else {
                emit(RunPath(nodeIndices: nodeIndices, edgeIndices: edgeIndices, termination: .end))
                return
            }

            // What the engine may do after `node`, in its order.
            var steps: [Step] = []
            var pending = [facts] // the ways of getting to the next edge: every earlier condition failed
            for edge in edges.indices where edges[edge].from == node.id && !pending.isEmpty {
                var next: [[ComparisonFact]] = []
                var mayThrow = false
                for facts in pending {
                    guard let condition = edges[edge].condition else {
                        steps.append(.take(edge: edge, facts: facts))
                        continue
                    }
                    for result in evaluate(condition, facts, on: nodeIndices) {
                        switch result.outcome {
                        case .holds: steps.append(.take(edge: edge, facts: result.facts))
                        case .fails: next.append(result.facts)
                        case .throws: mayThrow = true
                        }
                    }
                }
                if mayThrow { steps.append(.stop(.evaluationError(edge: edge))) }
                pending = next
            }
            if !pending.isEmpty { steps.append(.stop(.noMatchingEdge)) }

            for step in steps {
                switch step {
                case .stop(let termination):
                    emit(RunPath(nodeIndices: nodeIndices, edgeIndices: edgeIndices, termination: termination))
                case .take(let edge, let facts):
                    guard let target = nodeIndex[edges[edge].to] else {
                        emit(RunPath(nodeIndices: nodeIndices, edgeIndices: edgeIndices, termination: .missingNode(edge: edge)))
                        continue
                    }
                    guard !nodeIndices.contains(target) else {
                        emit(RunPath(nodeIndices: nodeIndices, edgeIndices: edgeIndices, termination: .cycle(edge: edge)))
                        continue
                    }
                    walk(nodeIndices + [target], edgeIndices + [edge], facts)
                }
            }
        }

        walk([start], [], [])
        return .init(paths: paths, isComplete: isComplete)
    }
}

/// A possible result of evaluating an edge condition in ``Workflow/Config/runPaths(context:limit:)``.
private enum ConditionOutcome {
    case holds, fails, `throws`
}

/// A comparison (``Condition/string(_:)`` or ``Condition/int(_:)``) the engine evaluated on a path, with its result,
/// after the node at `position` on the path.
private struct ComparisonFact {
    let comparison: Condition
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
