import Testing
import Yams

@testable import LLMFlow
import Foundation

@Test("testDataTypeDeclsLCA", arguments: [
    (
        [.single(.int), .single(.int)] as [FlowData.TypeDecl],
        .single(.int) as FlowData.TypeDecl
    ), (
        [.single(.string), .single(.string)] as [FlowData.TypeDecl],
        .single(.string)
    ), (
        [.single(.int), .single(.string)] as [FlowData.TypeDecl],
        .single(.any)
    ), (
        [.single(.string), .single(.int)] as [FlowData.TypeDecl],
        .single(.any)
    ), (
        [.list(.single(.int)), .list(.single(.int))] as [FlowData.TypeDecl],
        .list(.single(.int))
    ), (
        [.list(.single(.int)), .list(.single(.string))] as [FlowData.TypeDecl],
        .list(.single(.any))
    ), (
        [.map(.single(.int)), .map(.single(.int))] as [FlowData.TypeDecl],
        .map(.single(.int))
    ), (
        [.map(.single(.int)), .map(.single(.string))] as [FlowData.TypeDecl],
        .map(.single(.any))
    ), (
        [.list(.single(.int)), .map(.single(.string))] as [FlowData.TypeDecl],
        .any
    ), (
        [.list(.single(.int)), .list(.list(.single(.int)))] as [FlowData.TypeDecl],
        .list(.any)
    ), (
        [.map(.single(.int)), .map(.list(.single(.int)))] as [FlowData.TypeDecl],
        .map(.any)
    ),
])
func testDataTypeDeclsLCA(_ value: [FlowData.TypeDecl], expect: FlowData.TypeDecl) throws {
    let result = FlowData.TypeDecl.LCA(decls: value)
    #expect(result == expect)
}


@Test("testDataTypeConvertTo", arguments: [
    (
        .single(.int) as FlowData.TypeDecl,
        "Int"
    ), (
        .single(.string),
        "String"
    ), (
        .single(.any),
        "Any"
    ), (
        .list(.single(.int)),
        "[Int]"
    ), (
        .list(.single(.string)),
        "[String]"
    ), (
        .list(.single(.any)),
        "[Any]"
    ), (
        .map(.single(.int)),
        "[String: Int]"
    ), (
        .map(.single(.string)),
        "[String: String]"
    ), (
        .map(.single(.any)),
        "[String: Any]"
    )
])
func testDataTypeConvertTo(_ value: FlowData.TypeDecl, expect: String) throws {
    #expect(value.description == expect)
}

@Test("testDataTypeConvertFrom", arguments: [
    (
        "Int",
        .single(.int) as FlowData.TypeDecl
    ), (
        "String",
        .single(.string)
    ), (
        "Any",
        .single(.any)
    ), (
        "[Int]",
        .list(.single(.int))
    ), (
        "[String]",
        .list(.single(.string))
    ), (
        "[Any]",
        .list(.single(.any))
    ), (
        "[String: Int]",
        .map(.single(.int))
    ), (
        "[String: String]",
        .map(.single(.string))
    ), (
        "[String: Any]",
        .map(.single(.any))
    )
])
func testDataTypeConvertFrom(_ description: String, expect: FlowData.TypeDecl) throws {
    let value = FlowData.TypeDecl(description)
    #expect(value == expect)
}



@Test("testDataTypeEncode", arguments: [
    (
        .single(.int) as FlowData.TypeDecl,
        "Int"
    ), (
        .single(.string),
        "String"
    ), (
        .single(.any),
        "Any"
    ), (
        .list(.single(.int)),
        "'[Int]'"
    ), (
        .list(.single(.string)),
        "'[String]'"
    ), (
        .list(.single(.any)),
        "'[Any]'"
    ), (
        .map(.single(.int)),
        "'[String: Int]'"
    ), (
        .map(.single(.string)),
        "'[String: String]'"
    ), (
        .map(.single(.any)),
        "'[String: Any]'"
    )
])
func testDataTypeEncode(_ value: FlowData.TypeDecl, expect: String) throws {
    let encoder = YAMLEncoder()
    let encoded = try encoder.encode(value)
    
    #expect(encoded.trimmingCharacters(in: .whitespacesAndNewlines) == expect)
}

@Test("testDataTypeDecode", arguments: [
    (
        "Int",
        .single(.int) as FlowData.TypeDecl
    ), (
        "String",
        .single(.string)
    ), (
        "Any",
        .single(.any)
    ), (
        "'[Int]'",
        .list(.single(.int))
    ), (
        "'[String]'",
        .list(.single(.string))
    ), (
        "'[Any]'",
        .list(.single(.any))
    ), (
        "'[String: Int]'",
        .map(.single(.int))
    ), (
        "'[String: String]'",
        .map(.single(.string))
    ), (
        "'[String: Any]'",
        .map(.single(.any))
    )
])
func testDataTypeDecode(_ description: String, expect: FlowData.TypeDecl) throws {
    let decoder = YAMLDecoder()
    let decoded = try decoder.decode(FlowData.TypeDecl.self, from: description)
    #expect(decoded == expect)
}
