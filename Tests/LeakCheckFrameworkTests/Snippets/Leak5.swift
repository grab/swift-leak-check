//
//  File5.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 28/10/2019.
//

// https://gitlab.myteksi.net/mobile/dax-ios/driver-ios/merge_requests/6250
class X {
  func loadSettings() {
    dependencies.paymentService.cashSettingsStream.subscribe(weak: self, onNext: { `strongSelf`, _ in
      strongSelf.bankMethod = self.dependencies.paymentService.bankPayment // Leak
      strongSelf.updateViewModel()
    }).disposed(by: cashSettingDisposeBag)
  }
}
