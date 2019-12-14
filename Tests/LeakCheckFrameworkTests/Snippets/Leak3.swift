//
//  File3.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 28/10/2019.
//

// https://gitlab.myteksi.net/mobile/dax-ios/driver-ios/merge_requests/6827
class X {
  init(client: SafetyTelemetryHttpClient,
       dataStore: SafetyTelemetryDataStore,
       alertProcessor: SafetyAlertProcessor) {
    httpClient = client
    safetyDataStore = dataStore
    safetyAlertProcessor = alertProcessor
    
    safetyAlertProcessor.shouldSendAcceleratingTelemetry.map { self.mapAlert($0) } // Leak
      .filter { !$0.isEmpty }
      .subscribe(weak: self, onNext: { strongSelf, value in
        strongSelf.sendAcceleratingTelemetry(acceleration: value)
      }, onError: nil, onCompleted: nil, onDisposed: nil)
      .disposed(by: disposeBag)
    
    safetyAlertProcessor.shouldSendSpeedingTelemetry.map { self.mapAlert($0) } // Leak
      .filter { !$0.isEmpty }
      .subscribe(weak: self, onNext: { strongSelf, value in
        strongSelf.sendSpeedingTelemetry(speed: value)
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
