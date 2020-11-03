#
#  Created by teambition-ios on 2020/7/27.
#  Copyright © 2020 teambition. All rights reserved.
#     

Pod::Spec.new do |s|
  s.name             = 'snapper-swift'
  s.version          = '4.0.1'
  s.summary          = 'Snapper-core client by Swift for iOS/OS X'
  s.description      = <<-DESC
  Snapper-core client by Swift for iOS/OS X
                       DESC

  s.homepage         = 'https://github.com/teambition/Snapper-swift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'teambition mobile' => 'teambition-mobile@alibaba-inc.com' }
  s.source           = { :git => 'https://github.com/teambition/Snapper-swift.git', :tag => s.version.to_s }

  s.swift_version = '5.0'
  s.ios.deployment_target = '8.0'

  s.source_files = 'Snapper/Sources/*.swift'

end
