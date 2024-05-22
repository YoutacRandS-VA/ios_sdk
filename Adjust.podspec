Pod::Spec.new do |s|
  s.name           = "Adjust"
  s.version        = "5.0.0"
  s.summary        = "This is the iOS SDK of adjust. You can read more about it at http://adjust.com."
  s.homepage       = "https://github.com/adjust/ios_sdk"
  s.license        = { :type => 'MIT', :file => 'MIT-LICENSE' }
  s.author         = { "Adjust" => "sdk@adjust.com" }
  s.source         = { :git => "https://github.com/adjust/ios_sdk.git", :tag => "v#{s.version}" }
  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'
  s.framework      = 'SystemConfiguration'
  s.ios.weak_framework = 'AdSupport'
  s.tvos.weak_framework = 'AdSupport'
  s.requires_arc   = true
  s.default_subspec = 'Core'
  s.pod_target_xcconfig = { 'BITCODE_GENERATION_MODE' => 'bitcode' }

  s.subspec 'Core' do |co|
    co.source_files   = 'Adjust/*.{h,m}', 'Adjust/ADJAdditions/*.{h,m}'
    co.resource_bundle = {'Adjust' => ['Adjust/*.xcprivacy']}
  end

  s.subspec 'WebBridge' do |wb|
    wb.source_files = 'AdjustBridge/*.{h,m}', 'AdjustBridge/WebViewJavascriptBridge/*.{h,m}'
    wb.dependency 'Adjust/Core'
    wb.ios.deployment_target = '12.0'
  end
end
