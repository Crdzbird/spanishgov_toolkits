Pod::Spec.new do |s|
  s.name             = 'felectronic_dnie_ios'
  s.version          = '0.0.1'
  s.summary          = 'iOS implementation of the felectronic_dnie plugin.'
  s.description      = <<-DESC
iOS implementation for reading and signing with Spanish electronic DNIe
(Documento Nacional de Identidad electrónico) via NFC.
                       DESC
  s.homepage         = 'https://github.com/crdzbird/felectronic_dnie'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'crdzbird' => 'crdzbird@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'felectronic_dnie_ios/Sources/**/*.{swift,h,m}'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'SWIFT_OBJC_BRIDGING_HEADER' => '$(PODS_TARGET_SRCROOT)/felectronic_dnie_ios/Sources/felectronic_dnie_ios/ElectronicDnie-Bridging-Header.h',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) J2OBJC=1',
  }
  s.swift_version    = '5.0'
end
