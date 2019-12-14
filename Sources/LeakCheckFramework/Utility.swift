//
//  Utility.swift
//  LeakCheckFramework
//
//  Created by Hoang Le Pham on 05/12/2019.
//

import Foundation

extension Collection where Index == Int {
  subscript (safe index: Int) -> Element? {
    if index < 0 || index >= count {
      return nil
    }
    return self[index]
  }
}
