class X {
  func doSmth() {
    let block: ([Int], X) -> Void = { [weak self] a, x in
      guard let strongSelf = self else { return }
      a.map { val in
        strongSelf.process(val) // No Leak
      }
      x.map {
        strongSelf.process(val) // Leak
      }
    }

    doSmthWithBlock(block)

    let block: ([Int], X) -> Void = { a, x in
      a.map { val in
        self.process(val) // No Leak
      }
      x.map {
        self.process(val) // No Leak
      }
    }

    block()

    // TODO
//    var block2: ([Int] -> Void)!
//    block2 = { [weak self] a in
//      guard let strongSelf = self else { return }
//      a.map { val in
//        strongSelf.process(val)
//      }
//    }
  }

  func forEach() {
    x.forEach {
      self.doSmth() // No Leak
    }
  }

  func tupleClosure() {
    let (a, b) = (
      closure1: {
        self.doSmth() // No Leak
      },
      closure2: {
        self.doSmth() // Leak
      }
    )

    a()
    doSmthWithCallback(b)
  }

  func nonEscapeClosure() {
    let a = {
      self.doSmth() // No Leak
    }
    a()
  }
}
