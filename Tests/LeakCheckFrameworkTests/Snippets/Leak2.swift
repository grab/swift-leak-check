//
//  File2.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 27/10/2019.
//

import Foundation

// https://gitlab.myteksi.net/mobile/dax-ios/driver-ios/merge_requests/6251
class X {
  func test() {
    view.historySegmentRelayStream.filter { $0 == .weekly }.take(1)
      .subscribe(weak: self, onNext: { strongSelf, _ in
        if let lastWeek = strongSelf.weekCarouselCellModels.last {
          strongSelf.handleWeekSelected(lastWeek)
        }
        strongSelf.showSelectWeekTooltipIfNeeded { [weak self] in // Leak
          guard let strongSelf = self else { return }
          if strongSelf.view.historySegment == .weekly && strongSelf.weeklyModel.partnerStatementStatus == .available {
            innerSelf.showWeeklyStatementTooltipIfNeeded()
          }
        }
      }).disposed(by: disposeBag)
    
  }
}
