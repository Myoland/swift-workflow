import Foundation
import LLMFlow
import Testing
import Yams

/// `Workflow.Config.validate()` and `Workflow.Config.runPaths(limit:)`, through the public API only.
struct WorkflowValidateTests {
    /// START → a_id → END.
    static let base = """
        nodes:
          - id: start_id
            type: START
            inputs:
              query: String
          - id: a_id
            type: TEMPLATE
            template: "A: {{ workflow.inputs.query }}"
          - id: end_id
            type: END
        edges:
          - from: start_id
            to: a_id
          - from: a_id
            to: end_id

        """

    /// `query == "a"`, as an edge condition (YAML, indented for an edge).
    static let whenA = """
            condition:
              equal:
                variable: workflow.inputs.query
                value: a
        """

    /// START → a_id | b_id → END. `startEdges` are the edges out of START (edges[0...]); a_id and b_id go to END.
    static func branched(startEdges: String) -> String {
        """
        nodes:
          - id: start_id
            type: START
            inputs:
              query: String
          - id: a_id
            type: TEMPLATE
            template: "A"
          - id: b_id
            type: TEMPLATE
            template: "B"
          - id: end_id
            type: END
        edges:
        \(startEdges)
          - from: a_id
            to: end_id
          - from: b_id
            to: end_id

        """
    }

    func config(_ yaml: String) throws -> Workflow.Config {
        try YAMLDecoder().decode(Workflow.Config.self, from: yaml)
    }

    func rules(_ yaml: String) throws -> [String] {
        try config(yaml).validate().map(\.rule.rawValue)
    }

    func paths(_ yaml: String, limit: Int = Workflow.Config.defaultRunPathLimit) throws -> (ids: [[String]], complete: Bool) {
        let config = try config(yaml)
        let paths = config.runPaths(limit: limit)
        return (paths.paths.map { $0.nodeIndices.map { config.nodes[$0].id } }, paths.isComplete)
    }

    // MARK: Clean

    @Test("A linear workflow has no problems and one path")
    func baseIsClean() throws {
        let config = try config(Self.base)
        #expect(config.validate().isEmpty)
        let paths = config.runPaths()
        #expect(paths.isComplete)
        #expect(paths.paths == [Workflow.Config.RunPath(nodeIndices: [0, 1, 2], edgeIndices: [0, 1])])
    }

    // MARK: Type declarations

    @Test("START input types the decoder does not accept are reported")
    func typeDecl() {
        let config = Workflow.Config(
            nodes: [
                StartNode(id: "start_id", inputs: [
                    "query": .single(.string), "flag": .single(.bool), "nested": .list(.list(.single(.int))),
                    "items": .list(.single(.string)), "tags": .map(.single(.int)),
                ]),
                EndNode(id: "end_id", name: nil),
            ],
            edges: [.init(from: "start_id", to: "end_id", condition: nil)]
        )
        let problems = config.validate()
        #expect(problems.map(\.rule) == [.typeDecl, .typeDecl], "\(problems)")
        #expect(problems.map(\.path) == ["nodes[0].inputs.flag", "nodes[0].inputs.nested"])
        #expect(problems.first?.message.contains("Bool") == true)
    }

    @Test("Type declarations parse the whole value, exactly like the decoder")
    func typeDeclWholeValue() {
        let valid = ["String", "Int", "Any", "[String]", "[Int]", "[Any]", "[String: String]", "[String:Int]", "[String: Any]"]
        for value in valid {
            #expect(FlowData.TypeDecl(value) != nil, "\(value)")
        }
        let invalid = [
            "String\n", "Int\r\n", "Any\r", "String\u{85}", "String\u{2028}", "[String]\n", "[String: Int]\n",
            "String ", " String", "\nString", "String extra", "[String] x", "Int\nInt", "Bool", "string",
            "[[String]]", "[String: [Int]]", "",
        ]
        for value in invalid {
            #expect(FlowData.TypeDecl(value) == nil, "\(value.debugDescription)")
        }
    }

    @Test("A START type followed by a line break, spaces or extra tokens fails to decode (no crash)")
    func typeDeclBoundaryInYAML() {
        let values = [
            #""String\n""#, #""[String]\n""#, #""[String: Int]\r\n""#, "|\n        String", #""String ""#,
            #""String extra""#, #""Int Int""#, "Bool", "string",
        ]
        for value in values {
            let yaml = Self.base.replacingOccurrences(of: "      query: String\n", with: "      query: \(value)\n")
            #expect(throws: DecodingError.self, "\(value)") { try config(yaml) }
        }
    }

    // MARK: Structure

    @Test("Exactly one START and at least one END")
    func startAndEnd() throws {
        let noEnd = Self.base.replacingOccurrences(of: "    type: END", with: "    type: TEMPLATE\n    template: x")
        #expect(try rules(noEnd) == ["lint.end", "lint.no-exit"])
        #expect(try config(noEnd).validate().first?.path == "nodes")

        let twoStarts = Self.base.replacingOccurrences(
            of: "  - id: end_id\n", with: "  - id: start_two\n    type: START\n    inputs: {}\n  - id: end_id\n")
        let problems = try config(twoStarts).validate()
        #expect(problems.map(\.rule.rawValue) == ["lint.start", "lint.unreachable", "lint.no-exit"], "\(problems)")
        #expect(problems.first?.path == "nodes[2]")

        let noStart = Workflow.Config(nodes: [EndNode(id: "end_id", name: nil)], edges: [])
        #expect(noStart.validate().map(\.rule) == [.start])
        #expect(noStart.validate().first?.path == "nodes")
        #expect(noStart.runPaths().paths.isEmpty)
    }

    @Test("Node ids are unique")
    func duplicateID() throws {
        let yaml = Self.base.replacingOccurrences(of: "  - id: end_id", with: "  - id: a_id")
        let problems = try config(yaml).validate()
        #expect(problems.first?.rule == .duplicateID, "\(problems)")
        #expect(problems.first?.path == "nodes[2].id")
    }

    @Test("Edges reference existing nodes")
    func edgeReferences() throws {
        let missingTo = Self.base.replacingOccurrences(of: "    to: end_id", with: "    to: retry_short")
        let problems = try config(missingTo).validate()
        #expect(problems.contains { $0.rule == .edge && $0.path == "edges[1].to" && $0.message.contains("retry_short") })

        let missingFrom = Self.base + "  - from: ghost\n    to: end_id\n"
        #expect(try config(missingFrom).validate().map(\.path) == ["edges[2].from"])
    }

    @Test("Cycle")
    func cycle() throws {
        let yaml = Self.base.replacingOccurrences(
            of: "  - from: a_id\n    to: end_id\n",
            with: "  - from: a_id\n    to: b_id\n  - from: b_id\n    to: a_id\n  - from: b_id\n    to: end_id\n"
        ).replacingOccurrences(of: "  - id: end_id\n", with: "  - id: b_id\n    type: TEMPLATE\n    template: B\n  - id: end_id\n")
        let problems = try config(yaml).validate()
        #expect(problems.map(\.rule) == [.cycle], "\(problems)")
        #expect(problems.first?.path == "edges[2]")
        #expect(problems.first?.message.contains("a_id → b_id → a_id") == true)
        // Path enumeration terminates on a cycle: b_id's first edge (unconditional, back to a_id) is the only one taken.
        #expect(try paths(yaml).ids == [["start_id", "a_id", "b_id"]])
    }

    @Test("Every node is reachable from START")
    func unreachable() throws {
        let yaml = Self.base.replacingOccurrences(
            of: "  - id: end_id\n", with: "  - id: orphan_id\n    type: TEMPLATE\n    template: x\n  - id: end_id\n"
        ) + "  - from: orphan_id\n    to: end_id\n"
        let problems = try config(yaml).validate()
        #expect(problems.map(\.rule) == [.unreachable], "\(problems)")
        #expect(problems.first?.path == "nodes[2]")
    }

    // MARK: Where the engine stops

    @Test("A node without outgoing edges (other than END) has no exit")
    func noExit() throws {
        let yaml = Self.base.replacingOccurrences(of: "  - from: a_id\n    to: end_id\n", with: "  - from: start_id\n    to: end_id\n")
        let problems = try config(yaml).validate()
        #expect(problems.map(\.rule) == [.noExit], "\(problems)")
        #expect(problems.first?.path == "nodes[1]")
    }

    @Test("All outgoing edges conditional is a dead end, unless one always holds or they pair C / not C")
    func deadEnd() throws {
        let both = """
              - from: start_id
                to: a_id
                condition:
                  equal:
                    variable: workflow.inputs.query
                    value: a
              - from: start_id
                to: b_id
                condition:
                  equal:
                    variable: workflow.inputs.query
                    value: b
            """
        let stuck = try config(Self.branched(startEdges: both)).validate()
        #expect(stuck.map(\.rule) == [.deadEnd], "\(stuck)")
        #expect(stuck.first?.path == "nodes[0]")
        #expect(try paths(Self.branched(startEdges: both)).ids == [["start_id", "a_id", "end_id"], ["start_id", "b_id", "end_id"]])

        // C, then not C (either order): one of them always holds.
        let notA = """
              - from: start_id
                to: b_id
                condition:
                  not:
                    equal:
                      variable: workflow.inputs.query
                      value: a
            """
        let aEdge = "  - from: start_id\n    to: a_id\n" + Self.whenA
        #expect(try config(Self.branched(startEdges: aEdge + "\n" + notA)).validate().isEmpty)
        #expect(try config(Self.branched(startEdges: notA + "\n" + aEdge)).validate().isEmpty)

        // A condition that always holds is a fallback too: `and: []`, `not: {or: []}`.
        for fallback in ["      and: []", "      not:\n        or: []"] {
            let edges = aEdge + "\n  - from: start_id\n    to: b_id\n    condition:\n" + fallback
            #expect(try config(Self.branched(startEdges: edges)).validate().isEmpty, "\(fallback)")
        }
        // A condition that never holds is not.
        let never = aEdge + "\n  - from: start_id\n    to: b_id\n    condition:\n      or: []"
        #expect(try rules(Self.branched(startEdges: never)) == ["lint.dead-end"])
    }

    @Test("END stops the engine: edges out of END are reported and paths stop there")
    func endEdges() throws {
        let yaml = Self.base.replacingOccurrences(
            of: "    type: END\n", with: "    type: END\n  - id: after_id\n    type: TEMPLATE\n    template: x\n"
        ) + "  - from: end_id\n    to: after_id\n"
        let problems = try config(yaml).validate()
        #expect(problems.map(\.rule).contains(.endEdges), "\(problems)")
        #expect(problems.first { $0.rule == .endEdges }?.path == "edges[2]")
        #expect(try paths(yaml).ids == [["start_id", "a_id", "end_id"]])
    }

    // MARK: Paths

    @Test("Exclusive branches are separate paths, with the edges taken")
    func exclusiveBranches() throws {
        let edges = "  - from: start_id\n    to: a_id\n" + Self.whenA + "\n  - from: start_id\n    to: b_id"
        let config = try config(Self.branched(startEdges: edges))
        #expect(config.validate().isEmpty)
        let paths = config.runPaths()
        #expect(paths.isComplete)
        #expect(paths.paths == [
            Workflow.Config.RunPath(nodeIndices: [0, 1, 3], edgeIndices: [0, 2]),
            Workflow.Config.RunPath(nodeIndices: [0, 2, 3], edgeIndices: [1, 3]),
        ])
    }

    @Test("Edges after an unconditional or always-true edge are never taken; always-false edges neither")
    func unreachableFallback() throws {
        for first in [
            "  - from: start_id\n    to: a_id", "  - from: start_id\n    to: a_id\n    condition:\n      and: []",
            "  - from: start_id\n    to: a_id\n    condition:\n      not:\n        or: []",
        ] {
            let yaml = Self.branched(startEdges: first + "\n  - from: start_id\n    to: b_id")
            #expect(try paths(yaml).ids == [["start_id", "a_id", "end_id"]], "\(first)")
            let edges = try config(yaml).evaluatedEdges(from: "start_id")
            #expect(edges.indices == [0])
            #expect(edges.isExhaustive)
        }
        let alwaysFalse = Self.branched(
            startEdges: "  - from: start_id\n    to: a_id\n    condition:\n      or: []\n  - from: start_id\n    to: b_id")
        #expect(try paths(alwaysFalse).ids == [["start_id", "b_id", "end_id"]])
    }

    @Test("After C and not C, later edges are never evaluated")
    func complementStopsEvaluation() throws {
        let notA = "\n  - from: start_id\n    to: b_id\n    condition:\n      not:\n        equal:\n          variable: workflow.inputs.query\n          value: a"
        let edges = "  - from: start_id\n    to: a_id\n" + Self.whenA + notA + "\n  - from: start_id\n    to: end_id"
        let config = try config(Self.branched(startEdges: edges))
        let evaluated = config.evaluatedEdges(from: "start_id")
        #expect(evaluated.indices == [0, 1])
        #expect(evaluated.isExhaustive)
        #expect(try paths(Self.branched(startEdges: edges)).ids == [["start_id", "a_id", "end_id"], ["start_id", "b_id", "end_id"]])
    }

    /// START → `count` diamonds (each: a conditional and an unconditional branch) → END: 2^count paths.
    static func diamonds(_ count: Int) -> Workflow.Config {
        var nodes: [any RunnableNode] = [StartNode(id: "j0", inputs: ["query": .single(.string)])]
        var edges: [Workflow.Edge] = []
        let condition = Condition.string(.equal(variable: "workflow.inputs.query", value: "a"))
        for index in 0 ..< count {
            nodes += [TemplateNode(id: "a\(index)", name: nil, template: "a"), TemplateNode(id: "b\(index)", name: nil, template: "b")]
            nodes.append(TemplateNode(id: "j\(index + 1)", name: nil, template: "j"))
            edges += [
                .init(from: "j\(index)", to: "a\(index)", condition: condition),
                .init(from: "j\(index)", to: "b\(index)", condition: nil),
                .init(from: "a\(index)", to: "j\(index + 1)", condition: nil),
                .init(from: "b\(index)", to: "j\(index + 1)", condition: nil),
            ]
        }
        nodes.append(EndNode(id: "end", name: nil))
        edges.append(.init(from: "j\(count)", to: "end", condition: nil))
        return Workflow.Config(nodes: nodes, edges: edges)
    }

    @Test("Path enumeration stops at the limit (256 by default)")
    func pathCap() {
        #expect(Workflow.Config.defaultRunPathLimit == 256)
        #expect(Self.diamonds(3).validate().isEmpty)

        let eight = Self.diamonds(8).runPaths()
        #expect(eight.paths.count == 256)
        #expect(eight.isComplete)

        let nine = Self.diamonds(9).runPaths()
        #expect(nine.paths.count == 256)
        #expect(!nine.isComplete)

        let limited = Self.diamonds(3).runPaths(limit: 4)
        #expect(limited.paths.count == 4)
        #expect(!limited.isComplete)
        #expect(Self.diamonds(2).runPaths(limit: 4).isComplete)
    }

    // MARK: Conditions

    @Test("constantValue: true or false when a condition does not read the context, nil otherwise")
    func constantValue() {
        let read = Condition.string(.empty(variable: "x"))
        #expect(Condition.and([]).constantValue == true)
        #expect(Condition.or([]).constantValue == false)
        #expect(Condition.not(.or([])).constantValue == true)
        #expect(Condition.and([.and([]), read]).constantValue == nil)
        #expect(Condition.and([.or([]), read]).constantValue == false)
        #expect(Condition.or([.and([]), read]).constantValue == true)
        #expect(read.constantValue == nil)
        #expect(Condition.isExhaustive([read, nil]))
        #expect(Condition.isExhaustive([read, .not(read)]))
        #expect(Condition.isExhaustive([.not(read), read]))
        #expect(!Condition.isExhaustive([read, .or([])]))
        #expect(!Condition.isExhaustive([]))
    }

    @Test("Problems are Codable with a stable rule id")
    func problemCodable() throws {
        let problem = WorkflowProblem(rule: .deadEnd, message: "m", path: "nodes[0]")
        let data = try JSONEncoder().encode(problem)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains(#""rule":"lint.dead-end""#))
        #expect(try JSONDecoder().decode(WorkflowProblem.self, from: data) == problem)
    }
}
