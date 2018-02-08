# -*- encoding: utf-8 -*-
require File.expand_path('../lib/sequel-devise/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Rodrigo Rosenfeld Rosas", "Eugen Kuksa"]
  gem.email         = ["kuksa.eugen@gmail.com"]
  gem.description   = %q{Devise support for Sequel models}
  gem.summary       = %q{Enable Devise support by adding plugin :devise to your Sequel Model}
  gem.homepage      = "https://github.com/ontohub/sequel-devise"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "sequel-devise"
  gem.require_paths = ["lib"]
  gem.version       = Sequel::Devise::VERSION

  gem.add_dependency 'sequel', '>= 3.11.0'
  gem.add_dependency 'devise'
  gem.add_dependency 'orm_adapter-sequel'
end
