//
//  JsonSchemaTests.swift
//  dify-forward
//
//  Created by AFuture on 2025/4/19.
//

import DynamicJSON
import Testing
import Foundation


@Test("testDynamicJsonEncode")
func testDynamicJsonEncode() throws {
    let schema = try JSONSchema(string: """
    {
      "type": "object",
      "properties": {
        "first_name": { "type": "string" },
        "last_name": { "type": "string" },
        "birthday": { "type": "string", "format": "date" },
        "address": {
           "type": "object",
           "properties": {
             "street_address": { "type": "string" },
             "city": { "type": "string" },
             "state": { "type": "string" },
             "country": { "type" : "string" }
           }
        }
      }
    }
    """)
    let json = schema.jsonValue
    
    let encoder = JSONEncoder()
    let data = try encoder.encode(schema)
    print(String(data: data, encoding: .utf8)!)
}
