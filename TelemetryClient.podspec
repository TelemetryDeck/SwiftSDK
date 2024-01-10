Pod::Spec.new do |spec|
  spec.name         = "TelemetryDeck SDK"
  spec.version      = "1.5.0"
  spec.summary      = "Client SDK for TelemetryDeck"
  spec.swift_versions = "5.2"
  spec.summary  = "Swift SDK for TelemetryDeck, a privacy-first analytics service for apps. Sign up for a free account at telemetrydeck.com."
    spec.description  = <<-DESC
                      Build better products with live usage data. 
                      Capture and analyize users moving through your app 
                      and get help deciding how to grow, all without 
                      compromising privacy!

                      Setting up TelemetryDeck takes less than 10 minutes. 
                      Immediately after publishing your app, TelemetryDeck 
                      can show you a lot of base level information:

                      How many users are new to your app?
                      How many users are active?
                      Which versions of your app are people running, and 
                      on which operating system and device type are they?
                   DESC
  spec.homepage     = "https://telemetrydeck.com/?source=cocoapods"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author             = { "Daniel Jilg" => "daniel@telemetrydeck.com" }
  spec.ios.deployment_target = "12.0"
  spec.osx.deployment_target = "10.13"
  spec.watchos.deployment_target = "5.0"
  spec.tvos.deployment_target = "13.0"
  spec.source       = { :git => "https://github.com/TelemetryDeck/SwiftClient.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/**/*.{h,m,swift}"
end
