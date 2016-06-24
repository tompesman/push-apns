$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "push-apns/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "push-apns"
  s.version     = PushApns::VERSION
  s.authors     = ["Tom Pesman"]
  s.email       = ["tom@tnux.net"]
  s.homepage    = "https://github.com/tompesman/push-apns"
  s.summary     = "APNS (iOS/Apple) part of the modular push daemon."
  s.description = "APNS support for the modular push daemon."

  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.files         = `git ls-files lib`.split("\n") + ["README.md", "MIT-LICENSE"]
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "push-core", "~> 1.0.0"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec", "~> 3.4"
  s.add_development_dependency "rspec-rails", "~> 3.4"
  s.add_development_dependency "activerecord"
  s.add_development_dependency "multi_json"
end
