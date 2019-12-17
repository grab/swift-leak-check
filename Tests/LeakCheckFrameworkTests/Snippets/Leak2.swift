//
//  File2.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 27/10/2019.
//

import Foundation

class X {
  func test() {
    view.someThing.filter { $0 == .weekly }
      .take(1)
      .subscribe(weak: self, onNext: { strongSelf, _ in
        strongSelf.showSelectWeekTooltipIfNeeded { [weak self] in // Leak
          guard let strongSelf = self else { return }
          strongSelf.doSmth()
        }
      }).disposed(by: disposeBag)
    
  }
}
