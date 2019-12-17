class AClass {
  var x = 1
  func test() {
    let b = BClass()
    let block = { [weak self] in
      guard let strongSelf = self else { return }
      strongSelf.x = strongSelf.x + 1
      weak var strongSelf2 = strongSelf
      b.doSmth {
        guard let `self` = self else { return }
        self.x = 1
        guard let strongSelf2 = strongSelf2 else { return }
        strongSelf2.x = 1
        let strongSelf3 = strongSelf // Leak
        strongSelf3.x = 1
        strongSelf.x = 1// Leak
        let _ = strongSelf // Leak
      }
    }

    b.doSmth(completion: block)

    let nonEscapeBlock = {
      // self.x += 1 // TODO
    }
    b.doNonEscapeBlock(nonEscapeBlock)
  }
}

class BClass {
  var completion: (() -> Void)?
  func doSmth(completion: @escaping () -> Void) {
    self.completion = completion
  }
  func doNonEscapeBlock(_ block: () -> Void) {
    block()
  }
}

