import Testing

@testable import LLMFlow

@Test("Run workflow")
func testRunWorkflow() async throws {
    #expect(throws: Never.self) {
        try StartNode.verify(
            data: [
                "foo": 1
            ], decls: ["foo": .single(.int)])
    }

    #expect(throws: Never.self) {
        try StartNode.verify(
            data: [
                "foo": "a"
            ], decls: ["foo": .single(.string)])
    }

    #expect(throws: Never.self) {
        try StartNode.verify(
            data: [
                "foo": 1,
                "bar": "a",
            ],
            decls: [
                "foo": .single(.int),
                "bar": .single(.string),
            ])
    }

    #expect(throws: Never.self) {
        try StartNode.verify(
            data: [
                "foo": 1,
                "bar": "a",
                "baz": [1],
                "bazz": [1, "a"],
                "qux": ["foo": "a"],
                "quxx": ["foo": 1, "bar": "a"],
            ],
            decls: [
                "foo": .single(.int),
                "bar": .single(.string),
                "baz": .list(.single(.int)),
                "bazz": .list(.single(.any)),
                "qux": .map(.single(.string)),
                "quxx": .map(.single(.any)),
            ])
    }

    #expect(throws: StartNode.InitVerifyErr.inputDataNotFound(key: "foo")) {
        try StartNode.verify(data: [:], decls: ["foo": .single(.int)])
    }

    #expect(throws: StartNode.InitVerifyErr.inputDataTypeMissMatch(key: "foo")) {
        try StartNode.verify(data: ["foo": .single(.string("a"))], decls: ["foo": .single(.int)])
    }
}
