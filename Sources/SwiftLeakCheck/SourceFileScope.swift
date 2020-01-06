//
//  SourceFileScope.swift
//  SwiftLeakCheck
//
//  Created by Hoang Le Pham on 04/01/2020.
//

import SwiftSyntax

public class SourceFileScope: Scope {
  let node: SourceFileSyntax
  init(node: SourceFileSyntax, parent: Scope?) {
    self.node = node
    super.init(scopeNode: .sourceFileNode(node), parent: parent)
  }
}
