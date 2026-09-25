platform :ios, '16.0'
inhibit_all_warnings!
project 'ShogiCoachPoC.xcodeproj'

target 'ShogiCoachPoC' do
  pod 'yaneuraou_engine', :path => './native'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end
end
