Pod::Spec.new do |s|
  s.name         = 'ffmpeg-kit-macos-min-gpl'
  s.version      = '6.0'
  s.summary      = 'Stub podspec to satisfy discontinued ffmpeg-kit dependency'
  s.license      = { :type => 'GPL' }
  s.homepage     = 'https://github.com/arthenica/ffmpeg-kit'
  s.source       = { :git => 'https://github.com/arthenica/ffmpeg-kit.git' }
  s.platform     = :osx
  s.static_framework = true
  s.vendored_frameworks = 'Stub.framework'
  s.source_files = '**/*.h'
end
