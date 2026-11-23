//
//  WorkflowSchemaFixtureTests.swift
//  swift-workflow
//
//  Fixtures in Tests/Fixtures/WorkflowSchema are shared with the JSON Schema check in CI
//  (.github/workflows/workflow-schema.yml): `valid/` must pass schema/workflow.schema.json,
//  `invalid/` must fail it. These tests keep the schema and the decoder in agreement.
//

import Foundation
import Testing
import Yams

@testable import LLMFlow

private let fixturesURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures/WorkflowSchema")

private func fixtureNames(_ folder: String) -> [String] {
    let url = fixturesURL.appendingPathComponent(folder)
    let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    return names.filter { $0.hasSuffix(".yaml") }.sorted()
}

private func readFixture(_ folder: String, _ name: String) throws -> String {
    try String(contentsOf: fixturesURL.appendingPathComponent(folder).appendingPathComponent(name), encoding: .utf8)
}

@Test("Schema fixtures exist")
func testSchemaFixturesExist() {
    #expect(!fixtureNames("valid").isEmpty)
    #expect(!fixtureNames("invalid").isEmpty)
}

@Test("Every valid schema fixture decodes", arguments: fixtureNames("valid"))
func testValidSchemaFixtureDecodes(_ name: String) throws {
    let yaml = try readFixture("valid", name)
    let config = try YAMLDecoder().decode(Workflow.Config.self, from: yaml)
    #expect(!config.nodes.isEmpty)
}

@Test("Invalid START input types throw instead of crashing", arguments: fixtureNames("invalid").filter { $0.hasPrefix("start_input_") })
func testInvalidStartInputFixtureThrows(_ name: String) throws {
    let yaml = try readFixture("invalid", name)
    #expect(throws: DecodingError.self) {
        try YAMLDecoder().decode(Workflow.Config.self, from: yaml)
    }
}
