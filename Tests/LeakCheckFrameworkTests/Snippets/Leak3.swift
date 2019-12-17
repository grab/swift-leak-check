//
//  File3.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 28/10/2019.
//

class X {
  init(client: SafetyTelemetryHttpClient,
       dataStore: SafetyTelemetryDataStore,
       alertProcessor: SafetyAlertProcessor) {
    httpClient = client
    safetyDataStore = dataStore
    safetyAlertProcessor = alertProcessor
    
    safetyAlertProcessor.shouldSendAcceleratingTelemetry.map { self.mapAlert($0) } // Leak
      .subscribe(weak: self, onNext: { strongSelf, value in
        strongSelf.sendAcceleratingTelemetry(acceleration: value)
      }, onError: nil, onCompleted: nil, onDisposed: nil)
      .disposed(by: disposeBag)
  }
  
  func requestPollNotifyLocationViewed(notifyTimeInterval: TimeInterval, notifyRequestLimit: Int) {
    safetyShareLocationStatusRelayStream
      .distinctUntilChanged()
      .filter { $0 }
      .flatMapLatest { _ in
        return Observable<Int>
          .interval(notifyTimeInterval, scheduler: MainScheduler.instance)
          .take(notifyRequestLimit)
          .flatMapLatest { [weak self] _ in // Leak
            return self?.requestNotifyECViewed() ?? .just(false)
          }
          .filter { $0 }
          .take(1)
      }
      .subscribe(weak: self, onNext: { strongSelf, _ in
        strongSelf.notifyLocationViewedPublish.onNext(())
      }).disposed(by: pollingDisposeBag)
  }
}
