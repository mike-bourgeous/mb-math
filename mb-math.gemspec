require_relative 'lib/mb/m/version'

Gem::Specification.new do |spec|
  spec.name          = "mb-math"
  spec.version       = MB::M::VERSION
  spec.authors       = ["Mike Bourgeous"]
  spec.email         = ["mike@mikebourgeous.com"]

  spec.summary       = %q{Mathematical functions for my personal projects.}
  spec.homepage      = "https://github.com/mike-bourgeous/mb-math"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.1")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mike-bourgeous/mb-math"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'bigdecimal', '~> 3.1.8'
  spec.add_runtime_dependency 'prime', '~> 0.1.3'
  spec.add_runtime_dependency 'numo-narray', '~> 0.9.2.1'
  spec.add_runtime_dependency 'cmath', '~> 1.0.0'
  spec.add_runtime_dependency 'matrix', '~> 0.4.2'
  spec.add_runtime_dependency 'mb-util', '>= 0.1.21.usegit'
  spec.add_runtime_dependency 'numo-pocketfft', '~> 0.4.1'

  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'pry-doc'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.10.0'
  spec.add_development_dependency 'simplecov', '~> 0.21.2'
end
