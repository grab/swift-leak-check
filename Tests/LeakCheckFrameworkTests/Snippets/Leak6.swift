//
//  File6.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 28/10/2019.
//

// https://gitlab.myteksi.net/mobile/dax-ios/driver-ios/merge_requests/6150
class X {
  func x() {
    Observable
      .combineLatest(statusStream, activeVehicleIdStream)
      .subscribe(weak: self, onNext: { (_, combinedData) in
        let (status, activeVehicleIDs) = combinedData
        switch status {
        case .ready: self.requestHeatmapSettings(activeVehicleIDs: activeVehicleIDs) // Leak
        default: break
        }
      })
      .disposed(by: disposeBag)
  }
}
