//
//  File6.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 28/10/2019.
//

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
