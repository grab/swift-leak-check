class X {
  private func addressLabelAnimated(expand: Bool) {
    UIView.animate(
      withDuration: 0.3,
      animations: {
        self.resetAddressConstraints(expand: expand)
    }) { _ in
      self.addressLabel.isHidden = !expand
    }
    UIView.animate(withDuration: voiceDuration) {
      self.progressView.snp.remakeConstraints { make in
        make.left.top.bottom.equalToSuperview()
        make.width.equalTo(0)
      }
    }
    
    UIView.animate(withDuration: Double(duration), delay: 0, options: .curveEaseInOut, animations: {
      self.dynamicMaskView.snp.updateConstraints { make in
        make.height.equalTo(self.snp.height)
      }
    })
    
    animateIfNeeded(animated: animated, updateBlock: {
      self.prepaidDoublePaymentAlertView.alpha = 0
    })
  }
}

extension X {
  private func animateIfNeeded(animated: Bool, updateBlock: @escaping () -> Void) {
    if animated {
      UIView.animate(withDuration: 0.3) {
        updateBlock()
        self.layoutIfNeeded()
      }
    } else {
      updateBlock()
    }
  }
}
