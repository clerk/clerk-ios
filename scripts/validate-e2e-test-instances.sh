#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "optparse"
require "uri"

DEFAULT_KEY_NAMES = [
  "auth-email-code-password",
  "auth-multi-methods",
  "auth-phone-code",
  "auth-username-password-user-model",
  "session-task-choose-organization",
  "session-task-reset-password",
  "session-task-setup-mfa",
].freeze

Requirement = Struct.new(:description, :predicate, keyword_init: true)

def requirement(description, &predicate)
  Requirement.new(description: description, predicate: predicate)
end

def blank?(value)
  value.nil? || value.to_s.strip.empty?
end

def attribute(environment, name)
  environment.dig("user_settings", "attributes", name) || {}
end

def require_environment_shape
  requirement("environment payload includes auth_config, user_settings, and display_config") do |environment|
    environment["auth_config"].is_a?(Hash) &&
      environment["user_settings"].is_a?(Hash) &&
      environment["display_config"].is_a?(Hash)
  end
end

def require_public_sign_up
  requirement("public sign-up is enabled") do |environment|
    environment.dig("user_settings", "sign_up", "mode") == "public"
  end
end

def require_first_factor(name)
  requirement("#{name} is enabled as a first factor") do |environment|
    config = attribute(environment, name)
    config["enabled"] == true && config["used_for_first_factor"] == true
  end
end

def require_attribute_enabled(name)
  requirement("#{name} is enabled") do |environment|
    attribute(environment, name)["enabled"] == true
  end
end

def require_attribute_required(name)
  requirement("#{name} is required") do |environment|
    config = attribute(environment, name)
    config["enabled"] == true && config["required"] == true
  end
end

def require_second_factor(name)
  requirement("#{name} is enabled as a second factor") do |environment|
    config = attribute(environment, name)
    config["enabled"] == true && config["used_for_second_factor"] == true
  end
end

def require_multi_session
  requirement("multi-session mode is enabled") do |environment|
    environment.dig("auth_config", "single_session_mode") == false
  end
end

def require_delete_self
  requirement("self-serve account deletion is enabled") do |environment|
    environment.dig("user_settings", "actions", "delete_self") == true
  end
end

def require_legal_consent
  requirement("legal consent is enabled for sign-up") do |environment|
    environment.dig("user_settings", "sign_up", "legal_consent_enabled") == true
  end
end

def require_organizations
  requirement("organizations are enabled") do |environment|
    environment.dig("organization_settings", "enabled") == true
  end
end

def require_force_organization_selection
  requirement("force organization selection is enabled") do |environment|
    environment.dig("organization_settings", "force_organization_selection") == true
  end
end

def require_organization_creation
  requirement("organization creation is enabled") do |environment|
    environment.dig("organization_settings", "organization_creation_defaults", "enabled") == true
  end
end

BASE_REQUIREMENTS = [
  require_environment_shape,
  require_public_sign_up,
].freeze

REQUIREMENTS_BY_KEY_NAME = {
  "auth-email-code-password" => [
    require_first_factor("email_address"),
    require_attribute_enabled("password"),
    require_delete_self,
  ],
  "auth-legal-consent" => [
    require_first_factor("email_address"),
    require_attribute_enabled("password"),
    require_legal_consent,
  ],
  "auth-multi-methods" => [
    require_first_factor("email_address"),
    require_first_factor("phone_number"),
    require_attribute_enabled("password"),
    require_second_factor("authenticator_app"),
    require_second_factor("phone_number"),
    require_multi_session,
  ],
  "auth-phone-code" => [
    require_first_factor("phone_number"),
  ],
  "auth-username-password-user-model" => [
    require_first_factor("username"),
    require_attribute_enabled("password"),
    require_attribute_required("first_name"),
    require_attribute_required("last_name"),
  ],
  "session-task-choose-organization" => [
    require_first_factor("email_address"),
    require_organizations,
    require_force_organization_selection,
    require_organization_creation,
  ],
  "session-task-reset-password" => [
    require_first_factor("email_address"),
    require_attribute_enabled("password"),
  ],
  "session-task-setup-mfa" => [
    require_first_factor("email_address"),
    require_second_factor("authenticator_app"),
    require_second_factor("phone_number"),
  ],
}.freeze

options = {
  keys_file: ".keys.json",
  timeout: 20,
}

OptionParser.new do |parser|
  parser.banner = "Usage: scripts/validate-e2e-test-instances.sh [options] [key-name ...]"
  parser.on("--keys-file PATH", "Path to .keys.json") { |value| options[:keys_file] = value }
  parser.on("--timeout SECONDS", Integer, "HTTP timeout per instance") { |value| options[:timeout] = value }
end.parse!

key_names = ARGV.empty? ? DEFAULT_KEY_NAMES : ARGV
key_names = key_names.reject { |key_name| blank?(key_name) }.uniq

if key_names.empty?
  warn "No E2E key names were provided."
  exit 1
end

keys = {}
if File.exist?(options[:keys_file])
  keys = JSON.parse(File.read(options[:keys_file]))
elsif key_names.length > 1 || blank?(ENV["CLERK_E2E_PUBLISHABLE_KEY"])
  warn "Missing #{options[:keys_file]}. Run make fetch-test-keys or provide CLERK_E2E_PUBLISHABLE_KEY for a single key."
  exit 1
end

def key_entry(keys, key_name)
  entry = keys[key_name]
  entry.is_a?(Hash) ? entry : {}
end

def publishable_key_for(keys, key_name)
  selected_key_name = ENV["CLERK_E2E_KEY_NAME"]
  if (blank?(selected_key_name) || selected_key_name == key_name) && !blank?(ENV["CLERK_E2E_PUBLISHABLE_KEY"])
    return ENV["CLERK_E2E_PUBLISHABLE_KEY"].strip
  end

  key_entry(keys, key_name)["pk"].to_s.strip
end

def secret_key_for(keys, key_name)
  selected_key_name = ENV["CLERK_E2E_KEY_NAME"]
  if selected_key_name == key_name && !blank?(ENV["CLERK_E2E_SECRET_KEY"])
    return ENV["CLERK_E2E_SECRET_KEY"].strip
  end

  key_entry(keys, key_name)["sk"].to_s.strip
end

def frontend_api_url_for(publishable_key)
  unless publishable_key.start_with?("pk_test_", "pk_live_")
    raise "publishable key has an invalid prefix"
  end

  encoded = publishable_key.split("_", 3).fetch(2)
  encoded = encoded.delete_suffix("$")
  padding = (4 - encoded.length % 4) % 4
  decoded = Base64.urlsafe_decode64(encoded + ("=" * padding))
  host = decoded.delete_suffix("$")

  raise "publishable key does not decode to a frontend API host" if blank?(host)

  URI("https://#{host}")
rescue KeyError, ArgumentError
  raise "publishable key could not be decoded"
end

def fetch_environment(frontend_api_url, timeout)
  uri = frontend_api_url.dup
  uri.path = "/v1/environment"
  uri.query = "_is_native=true"

  response = Net::HTTP.start(
    uri.host,
    uri.port,
    use_ssl: uri.scheme == "https",
    open_timeout: timeout,
    read_timeout: timeout
  ) do |http|
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"
    http.request(request)
  end

  unless response.is_a?(Net::HTTPSuccess)
    raise "GET /v1/environment failed with HTTP #{response.code}"
  end

  JSON.parse(response.body)
end

def requirements_for(key_name)
  BASE_REQUIREMENTS + (REQUIREMENTS_BY_KEY_NAME[key_name] || [])
end

def report_failure(failure)
  if ENV["GITHUB_ACTIONS"] == "true"
    warn "::error::#{failure}"
  else
    warn "  - #{failure}"
  end
end

failures = []

key_names.each do |key_name|
  publishable_key = publishable_key_for(keys, key_name)
  if blank?(publishable_key)
    failures << "#{key_name}: missing publishable key"
    next
  end

  if key_name == "session-task-reset-password" && blank?(secret_key_for(keys, key_name))
    failures << "#{key_name}: missing secret key"
  end

  begin
    frontend_api_url = frontend_api_url_for(publishable_key)
    environment = fetch_environment(frontend_api_url, options[:timeout])
  rescue StandardError => error
    failures << "#{key_name}: #{error.message}"
    next
  end

  missing_requirements = requirements_for(key_name).reject { |requirement| requirement.predicate.call(environment) }
  if missing_requirements.empty?
    puts "✅ #{key_name}: frontend environment preflight passed"
  else
    missing_requirements.each do |requirement|
      failures << "#{key_name}: #{requirement.description}"
    end
  end

  unless REQUIREMENTS_BY_KEY_NAME.key?(key_name)
    warn "⚠️  #{key_name}: no key-specific capability map exists; validated fetch/decode only"
  end
end

if failures.empty?
  puts "✅ E2E test instance preflight passed"
else
  warn "❌ E2E test instance preflight failed:"
  failures.each { |failure| report_failure(failure) }
  exit 1
end
