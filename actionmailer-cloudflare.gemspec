require_relative "lib/action_mailer_cloudflare/version"

Gem::Specification.new do |spec|
  spec.name = "actionmailer-cloudflare"
  spec.version = ActionMailerCloudflare::VERSION
  spec.authors = [ "Dave Bradford" ]
  spec.email = [ "dbradford@hey.com" ]
  spec.summary = "An ActionMailer delivery method for Cloudflare Email Sending's send_raw API."
  spec.homepage = "https://github.com/zerobearing2/actionmailer-cloudflare"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE.txt"]

  spec.add_dependency "actionmailer", ">= 7.2", "< 9"
end
