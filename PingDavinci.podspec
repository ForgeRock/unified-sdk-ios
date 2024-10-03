#
# Be sure to run `pod lib lint PingDavinci.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingDavinci'
  s.version          = '0.9.0-beta2'
  s.summary          = 'PingDavinci SDK for iOS'
  s.description      = <<-DESC
  The PingDavinci SDK is a powerful and flexible library for Authentication and Authorization. It is designed to be easy to use and extensible. It provides a simple API for navigating the authentication flow and handling the various states that can
occur during the authentication process.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/unified-sdk-ios.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingDavinci'
  s.swift_versions = ['5.0', '5.1']

  s.ios.deployment_target = '13.0'

  base_dir = "PingDavinci/PingDavinci"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'PingDavinci' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingOidc', '~> 0.9.0-beta2'
    
end
