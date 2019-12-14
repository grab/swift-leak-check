//
//  SyntaxRetrieval.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 09/12/2019.
//

import SourceKittenFramework
import SwiftSyntax

public enum SyntaxRetrieval {
  public static func request(content: String) throws -> SourceFileSyntax {
    let file = File(contents: content)
    let request = Request.syntaxTree(file: file, byteTree: false)
    let response = try request.send()
    let syntaxTreeJson = response["key.serialized_syntax_tree"] as! String
    let syntaxTreeData = syntaxTreeJson.data(using: .utf8)!
    let deserializer = SyntaxTreeDeserializer()
    return try deserializer.deserialize(syntaxTreeData, serializationFormat: .json)
  }
}
