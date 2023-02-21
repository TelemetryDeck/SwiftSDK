Pod::Spec.new do |spec|
  spec.name         = "TelemetryClient"
  spec.version      = "1.4.2"
  spec.summary      = "Client SDK for TelemetryDeck"
  spec.swift_versions = "5.2"
  spec.description  = "This package allows you to send signals to TelemetryDeck from your Swift code. Sign up for a free account at telemetrydeck.com."
  spec.homepage     = "https://github.com/TelemetryDeck/SwiftClient"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author             = { "Daniel Jilg" => "daniel@telemetrydeck.com" }
  spec.ios.deployment_target = "12.0"
  spec.osx.deployment_target = "10.13"
  spec.watchos.deployment_target = "5.0"
  spec.tvos.deployment_target = "13.0"
  spec.source       = { :git => "https://github.com/TelemetryDeck/SwiftClient.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/**/*.{h,m,swift}"
end
