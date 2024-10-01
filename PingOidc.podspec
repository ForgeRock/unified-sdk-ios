#
# Be sure to run `pod lib lint PingOidc.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PingOidc'
  s.version          = '0.9.0'
  s.summary          = 'PingOidc SDK for iOS'
  s.description      = <<-DESC
  The PingOidc SDK provides OIDC client for PingOne and ForgeRock platform..
                       DESC
  s.homepage         = 'https://www.pingidentity.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Ping Identity'

  s.source           = {
      :git => 'https://github.com/ForgeRock/unified-sdk-ios.git',
      :tag => s.version.to_s
  }

  s.module_name   = 'PingOidc'

  s.ios.deployment_target = '13.0'

  base_dir = "PingOidc/PingOidc"
  s.source_files = base_dir + '/**/*.swift', base_dir + '/**/*.h'
  s.resource_bundles = {
    'PingOidc' => [base_dir + '/*.xcprivacy']
  }
  
  s.ios.dependency 'PingOrchestrate', '~> 0.9.0'
end
