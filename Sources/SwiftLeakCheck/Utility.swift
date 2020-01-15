//
//  Utility.swift
//  SwiftLeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
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
