
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ruboty/typetalk/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruboty-typetalk'
  spec.version       = Ruboty::Typetalk::VERSION
  spec.authors       = ['pyama86']
  spec.email         = ['pyama@pepabo.com']

  spec.summary       = 'typetalk ruboty adapter.'
  spec.description   = 'typetalk rubyty adapter.'
  spec.homepage      = 'https://github.com/pyama86/ruboty-typetalk'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 10.0'

  spec.add_dependency 'faraday', '~> 0.14'
  spec.add_dependency 'ruboty', '>= 1.3'
  spec.add_dependency 'websocket-client-simple', '~> 0.3.0'
end
