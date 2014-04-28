# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'delay_many/version'

Gem::Specification.new do |spec|
  spec.name          = 'delay_many'
  spec.version       = DelayMany::VERSION
  spec.authors       = ['Robin Roestenburg']
  spec.email         = ['robin@roestenburg.io']
  spec.description   = %q{
    DelayMany makes it possible to delay saving ActiveRecord associations until
    the parent object is validated.
  }
  spec.summary       = %q{Delay saving ActiveRecord associations until parent is validated}
  spec.homepage      = 'http://github.com/robinroestenburg/delay_many'
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '> 3.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'appraisal'
end