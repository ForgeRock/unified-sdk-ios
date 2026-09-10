#
# Be sure to run `pod lib lint PingRecognize.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingRecognize'
  s.version          = '2.1.0'
  s.summary          = 'PingOne Recognize biometric authentication module for the Ping iOS SDK'
  s.description      = <<-DESC
    PingOne Recognize biometric authentication module for the Ping iOS SDK
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/ping-ios-sdk.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingRecognize'
  s.swift_versions = ['5.0', '5.1', '6.0']
  s.static_framework = true

  s.ios.deployment_target = '16.0'

  base_dir = "Recognize/Recognize"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.h'
  s.resource_bundles = {
    'Recognize' => [base_dir + '/*.xcprivacy']
  }

  s.ios.dependency 'PingJourneyPlugin', '~> 2.1.0'
  s.ios.dependency 'KeylessSDK', '~> 6.0'
end
