//
//  File4.swift
//  LeakCheckFrameworkTests
//
//  Created by Hoang Le Pham on 28/10/2019.
//

class X {
  private func createProfileV3Item() -> NavigatorItem {
    return RevampedProfileV2Builder.build(
      dependencies:
      (
        services: services,
        userSettings: userSettings,
        creds: loginInfo.creds,
        sandboxEndpoint: GrabEnvironment.discoveryHubSandboxEndPoint,
        deepLinkHandler: deepLinkHandler,
        analytics: analytics,
        analyticsTracker: tracker,
        navProviderService: navProviderService,
        isBenefitsHomeDesignV21Enabled: isBenefitsHomeDesignV21Enabled(),
        favLocationFactory: { self.createFavLocationVC() } // Leak
      ),
      output: self
    )
  }
}
