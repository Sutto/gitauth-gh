# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{gitauth-gh}
  s.version = "0.0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Darcy Laycock"]
  s.date = %q{2009-09-17}
  s.default_executable = %q{gitauth-gh}
  s.email = %q{sutto@sutto.net}
  s.executables = ["gitauth-gh"]
  s.files = ["bin/gitauth-gh", "lib/git_hub_api.rb", "lib/gitauth", "lib/gitauth/gh_mirror.rb"]
  s.homepage = %q{http://sutto.net/}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.2}
  s.summary = %q{Automatic mirror for github -> gitauth}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<brownbeagle-gitauth>, [">= 0.0.4.5"])
      s.add_runtime_dependency(%q<httparty>, [">= 0"])
    else
      s.add_dependency(%q<brownbeagle-gitauth>, [">= 0.0.4.5"])
      s.add_dependency(%q<httparty>, [">= 0"])
    end
  else
    s.add_dependency(%q<brownbeagle-gitauth>, [">= 0.0.4.5"])
    s.add_dependency(%q<httparty>, [">= 0"])
  end
end
