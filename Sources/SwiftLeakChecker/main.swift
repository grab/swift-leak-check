//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//

import Foundation
import SwiftLeakCheck

enum CommandLineError: Error, LocalizedError {
  case missingFileName
  
  var errorDescription: String? {
    switch self {
    case .missingFileName:
      return "Missing file or directory name"
    }
  }
}

do {
  let arguments = CommandLine.arguments
  guard arguments.count > 1 else {
    throw CommandLineError.missingFileName
  }
  
  let path = arguments[1]
  let url = URL(fileURLWithPath: path)
  let dirScanner = DirectoryScanner(callback: { fileUrl, shouldStop in
    do {
      guard fileUrl.pathExtension == "swift" else {
        return
      }
      
      print("Scan \(fileUrl)")
      
      let leakDetector = GraphLeakDetector()
      leakDetector.nonEscapeRules = [
        UIViewAnimationRule(),
        UIViewControllerAnimationRule(),
        DispatchQueueRule()
        ] + CollectionRules.rules
      
      let startDate = Date()
      let leaks = try leakDetector.detect(fileUrl)
      let endDate = Date()
      
      print("Finished in \(endDate.timeIntervalSince(startDate)) seconds")
      
      leaks.forEach { leak in
        print(leak.description)
      }
    } catch {}
  })
  
  dirScanner.scan(url: url)
  
} catch {
  print("\(error.localizedDescription)")
}

