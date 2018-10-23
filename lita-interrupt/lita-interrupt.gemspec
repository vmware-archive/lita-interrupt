# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'lita-interrupt'
  spec.version       = '0.1.0'
  spec.authors       = ['Oliver Albertini']
  spec.email         = ['oalbertini@pivotal.io']
  spec.description   = 'Interrupt the right people on slack'
  spec.summary       = 'Talks to the trello api to find out who to interrupt, then pings them on slack.'
  spec.homepage      = 'http://example.com'
  spec.license       = 'none'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'lita', '>= 4.7'
  spec.add_runtime_dependency 'lita-exclusive-route'
  spec.add_runtime_dependency 'ruby-trello'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.0.0'
end
