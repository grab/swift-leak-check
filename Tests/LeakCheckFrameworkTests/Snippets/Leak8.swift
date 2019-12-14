//
//  NoLeak1.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 30/10/2019.
//

class X {
  func test() {
    let a = A()
    // Capture self in nested closure
    a.block {
      tableView.rx.observe(CGSize.self, contentSizeText).unwrap() // No Leak
        .subscribe(onNext: { [weak self] size in // Leak
          guard let `self` = self else { return } // No Leak
      })
    }
    
    keyboardFrame().subscribeOn(MainScheduler.instance).subscribe(onNext: { [unowned self] frame in
      self.moveNextButtonAboveKeyboard(keyboardFrame: frame) // No Leak
    }).disposed(by: disposeBag)
  }
}
