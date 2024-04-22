Pod::Spec.new do |spec|
  spec.name         = "tss-client-swift"
  spec.version      = "4.0.1"
  spec.ios.deployment_target = '13.0'
  spec.summary      = "MPC TSS Client"
  spec.homepage     = "https://web3auth.io/"
  spec.license      = { :type => 'BSD', :file => 'License.md' }
  spec.swift_version   = "5.0"
  spec.author       = { "Torus Labs" => "hello@tor.us" }
  spec.source       = { :git => "https://github.com/torusresearch/tss-client-swift.git", :tag => spec.version }
  spec.source_files = "Sources/**/*.{swift,h,c}"
  spec.vendored_frameworks = "Sources/libdkls/libdkls.xcframework"
  spec.dependency 'curvelib.swift', '~> 1.0.1'
  spec.dependency 'BigInt', '~> 5.0.0'
  spec.dependency 'Socket.IO-Client-Swift', '16.1.0'
  spec.dependency "Starscream", "4.0.6"
  spec.module_name = "tssClientSwift"
end
