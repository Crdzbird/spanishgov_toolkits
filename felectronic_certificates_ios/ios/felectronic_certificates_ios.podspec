Pod::Spec.new do |s|
  s.name             = 'felectronic_certificates_ios'
  s.version          = '1.0.0'
  s.summary          = 'iOS implementation of the felectronic_certificates plugin.'
  s.description      = <<-DESC
iOS implementation for managing device-stored certificates
(import, sign, list, delete) using the Security framework and Keychain.
                       DESC
  s.homepage         = 'https://github.com/Crdzbird/spanishgov_toolkits'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'crdzbird' => 'luisalfonsocb83@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'felectronic_certificates_ios/Sources/**/*.{swift,h,m}'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version    = '5.0'
end
