import Foundation
import LLMFlow
import Testing
import Yams

/// A reference that indexes past the end of a list (or before its start) throws instead of crashing the process.
struct ReferenceOutOfRangeTests {
    static let store: Context.Store = ["workflow": ["inputs": ["items": ["a", "b"] as [AnySendable]] as [String: AnySendable]]]

    @Test("Request `$` references: in range resolves, out of range throws a DecodingError at the field", arguments: [
        ("workflow.inputs.items.2", 2), ("workflow.inputs.items.-1", -1), ("workflow.inputs.items.99", 99),
    ])
    func requestReference(reference: String, index: Int) throws {
        let ok = try ModelDecl(["$content": "workflow.inputs.items.1"]).render(Self.store)
        #expect(ok["content"] as? String == "b")

        let decl = ModelDecl(["$content": .single(.string(reference))])
        do {
            _ = try decl.render(Self.store)
            Issue.record("expected an error for \(reference)")
        } catch let DecodingError.dataCorrupted(context) {
            #expect(context.codingPath.map(\.stringValue) == ["$content"])
            let underlying = try #require(context.underlyingError as? ContextStorePath.IndexOutOfRangeError)
            #expect(underlying.index == index)
            #expect(underlying.count == 2)
            #expect(underlying.path.description == reference)
        }
    }

    @Test("Request `$` references nested in lists and maps report the coding path")
    func nestedRequestReference() throws {
        let decl = try YAMLDecoder().decode(ModelDecl.self, from: """
            stream: false
            inputs:
              - type: text
                role: user
                content: hi
              - type: text
                role: user
                "$content": workflow.inputs.items.5
            """)
        do {
            _ = try decl.render(Self.store)
            Issue.record("expected an error")
        } catch let DecodingError.dataCorrupted(context) {
            #expect(context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue } == ["inputs", "1", "$content"])
        }
    }

    @Test("Conditions: out of range throws from evaluate(_:), and eval(_:) is false instead of crashing", arguments: [
        "workflow.inputs.items.2", "workflow.inputs.items.-1",
    ])
    func condition(variable: String) throws {
        let condition = Condition.string(.equal(variable: ContextStorePath(variable), value: "a"))
        #expect(throws: ContextStorePath.IndexOutOfRangeError.self) { try condition.evaluate(Self.store) }
        #expect(throws: ContextStorePath.IndexOutOfRangeError.self) { try Condition.not(condition).evaluate(Self.store) }
        #expect(throws: ContextStorePath.IndexOutOfRangeError.self) {
            try Condition.int(.greater(variable: ContextStorePath(variable), value: 1)).evaluate(Self.store)
        }
        #expect(condition.eval(Self.store) == false)
        #expect(Condition.not(condition).eval(Self.store) == false)

        let inRange = Condition.string(.equal(variable: "workflow.inputs.items.0", value: "a"))
        #expect(try inRange.evaluate(Self.store))
        #expect(inRange.eval(Self.store))
        // A missing key is not an error: the condition does not hold.
        #expect(try !Condition.string(.equal(variable: "workflow.inputs.nope.0", value: "a")).evaluate(Self.store))
    }

    @Test("Context lookups out of range return nil")
    func contextLookup() {
        let context = Context(store: Self.store)
        #expect(context["workflow.inputs.items.1"] as? String == "b")
        #expect(context["workflow.inputs.items.2"] == nil)
        #expect(context["workflow.inputs.items.-1"] == nil)
    }

    struct Locator: ServiceLocator {
        func resolve<T>(shared _: T.Type) -> T? { nil }
        func resolve<T>(for _: (some Any).Type, as _: T.Type) -> T? { nil }
    }

    @Test("The engine throws when an edge condition reads past the end of a list")
    func engine() async throws {
        let config = try YAMLDecoder().decode(Workflow.Config.self, from: """
            nodes:
              - id: start_id
                type: START
                inputs:
                  items: "[String]"
              - id: end_id
                type: END
            edges:
              - from: start_id
                to: end_id
                condition:
                  equal:
                    variable: workflow.inputs.items.3
                    value: a
              - from: start_id
                to: end_id
            """)
        let workflow = try Workflow(config: config, locator: Locator())
        let inputs: [String: FlowData] = ["items": .list(.init(elements: ["a"]))]
        await #expect(throws: ContextStorePath.IndexOutOfRangeError.self) {
            for try await _ in try workflow.run(inputs: inputs) {}
        }
        // In range, the run reaches END.
        var types: [Workflow.PipeStateType] = []
        for try await state in try workflow.run(inputs: ["items": .list(.init(elements: ["a", "b", "c", "d"]))]) {
            types.append(state.type)
        }
        #expect(types.last == .end)
    }
}
