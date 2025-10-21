import Jinja
import Testing

@testable import LLMFlow

@Test("testRenderSimpleTemplate")
func renderSimpleTemplate() throws {
    // Create a map with string values
    let elements: [String: FlowData] = [
        "name": "John",
        "greeting": "Hello",
    ]

    let template = "{{ greeting }}, {{ name }}!"

    let result = try Template(template).render(elements.asAny.compactMapValues { try? .init(any: $0) })
    #expect(result == "Hello, John!")
}

@Test("testRenderSimpleTemplate")
func renderSimpleTemplat222e() throws {
    // Create a map with string values
    let elements: [String: FlowData] = [
        "name": ["John", "Tom"],
    ]

    let value = elements["name"]?.asAny
    let pp = value as? [String: [String]]
    print(pp as Any)
}

@Test("testRenderConditionalTemplate")
func renderConditionalTemplate() throws {
    let elements: [String: FlowData] = [
        "name": "John",
        "age": 30,
    ]

    let template = """
    {% if age == 30 %}
    {{ name }} is thirty years old.
    {% else %}
    {{ name }} is not thirty years old.
    {% endif %}
    """

    let result = try Template(template).render(elements.asAny.compactMapValues { try? .init(any: $0) })
    #expect(result.trimmingCharacters(in: .whitespacesAndNewlines) == "John is thirty years old.")
}

@Test("testRenderNestedTemplate")
func renderNestedTemplate() throws {
    // Create a nested structure with a map inside a map
    let context: [String: FlowData] = [
        "name": "John",
        "address": [
            "street": "123 Main St",
            "city": "New York",
            "zipcode": "10001",
        ],
    ]
    let template = """
    Name: {{ name }}
    Address:
        Street: {{ address.street }}
        City: {{ address.city }}
        Zipcode: {{ address.zipcode }}
    """
    let expected = """
    Name: John
    Address:
        Street: 123 Main St
        City: New York
        Zipcode: 10001
    """

    let result = try Template(template).render(context.asAny.compactMapValues { try? .init(any: $0) })
    #expect(result == expected)
}

@Test("testListInJinja")
func listInJinja() throws {
    let context: [String: FlowData] = [
        "names": [
            "Alice",
            "Bob",
            "Charlie",
        ],
    ]
    let template =
        """
        {% for name in names %}
        - {{ name }}
        {% endfor %}
        length: {{ names|length }}
        first: {{ names|first }}
        """
    let expected =
        """
        - Alice
        - Bob
        - Charlie
        length: 3
        first: Alice
        """

    let result = try Template(template, with: .init(trimBlocks: true)).render(context.asAny.compactMapValues { try? .init(any: $0) })
    #expect(result == expected)
}
