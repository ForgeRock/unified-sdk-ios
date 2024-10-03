#
# Be sure to run `pod lib lint PingStorage.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingStorage'
  s.version          = '0.9.0-beta2'
  s.summary          = 'PingStorage SDK for iOS'
  s.description      = <<-DESC
  The PingStorage SDK provides a flexible storage interface and a set of common storage solutions for the Ping SDKs.
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/unified-sdk-ios.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingStorage'

  s.ios.deployment_target = '13.0'

  base_dir = "PingStorage/PingStorage"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.c', base_dir + '/**/*.h'
  s.resource_bundles = {
    'PingStorage' => [base_dir + '/*.xcprivacy']
  }
end
