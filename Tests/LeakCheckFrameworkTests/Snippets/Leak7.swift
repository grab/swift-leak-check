//
//  File7.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 28/10/2019.
//

class X {
  func x() {
    viewModel.outputs.goToAllSettingsStream
      .subscribe(weak: self, onNext: { strongSelf, _ in
        let router = AllSettingsListRouter(
          email: strongSelf.loginInfo.creds.email,
          settings: strongSelf.settings,
          navProviderService: strongSelf.navProviderService,
          services: strongSelf.services,
          analytics: strongSelf.analytics,
          analyticsTracker: strongSelf.analyticsTracker,
          output: self // Leak
        )
        strongSelf.display(router, mode: .push, animated: true)
        GBLogDebug("allSettings tap")
      }).disposed(by: disposeBag)
  }
}
