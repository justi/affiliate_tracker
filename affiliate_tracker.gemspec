# frozen_string_literal: true

require_relative "lib/affiliate_tracker/version"

Gem::Specification.new do |spec|
  spec.name = "affiliate_tracker"
  spec.version = AffiliateTracker::VERSION
  spec.authors = ["Justyna Wojtczak"]
  spec.email = ["justine84@gmail.com"]

  spec.summary = "Simple affiliate link tracking for Rails"
  spec.description = "A Rails engine for tracking affiliate link clicks with redirect support and monitoring dashboard."
  spec.homepage = "https://github.com/justi-blue/affiliate_tracker"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/justi-blue/affiliate_tracker/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 8.0", "< 10"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "sqlite3", "~> 2.0"
end
