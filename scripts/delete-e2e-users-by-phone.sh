#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "timeout"
require "uri"

phone_number = ARGV.fetch(0) do
  warn "Usage: scripts/delete-e2e-users-by-phone.sh PHONE_NUMBER"
  exit 1
end
digits = phone_number.gsub(/\D/, "")

unless digits.match?(/\A5555550(?:1\d\d)\z/)
  warn "Refusing to delete users outside the approved 5555550100...5555550199 test range."
  exit 1
end

publishable_key = ENV.fetch("CLERK_E2E_PUBLISHABLE_KEY", "").strip
secret_key = ENV.fetch("CLERK_E2E_SECRET_KEY", "").strip

if publishable_key.empty? || secret_key.empty?
  warn "CLERK_E2E_PUBLISHABLE_KEY and CLERK_E2E_SECRET_KEY are required for phone-user cleanup."
  exit 1
end

def frontend_api_host(publishable_key)
  encoded = publishable_key.split("_", 3).fetch(2).delete_suffix("$")
  encoded += "=" * ((4 - encoded.length % 4) % 4)
  Base64.urlsafe_decode64(encoded).delete_suffix("$")
rescue ArgumentError, IndexError
  raise "Unable to decode the Clerk publishable key."
end

def backend_api_base_url(publishable_key)
  override = ENV.fetch("CLERK_E2E_BACKEND_API_URL", "").strip
  return URI(override.delete_suffix("/")) unless override.empty?

  host = frontend_api_host(publishable_key)
  return URI("https://api.clerkstage.dev") if host.include?("accountsstage") || host.include?("clerkstage")
  return URI("https://api.lclclerk.com") if host.include?("lclclerk")

  URI("https://api.clerk.com")
end

def perform_request(uri, request, attempts: 3)
  attempts.times do |attempt|
    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: 20,
      read_timeout: 30
    ) do |http|
      http.request(request)
    end

    return response if response.is_a?(Net::HTTPSuccess)

    retryable = response.code.to_i == 429 || response.code.to_i >= 500
    raise "Backend API request failed with HTTP #{response.code}." unless retryable && attempt + 1 < attempts

    sleep(2**attempt)
  rescue IOError, SystemCallError, Timeout::Error => error
    raise error if attempt + 1 >= attempts

    sleep(2**attempt)
  end
end

def authorized_request(request, secret_key)
  request["Authorization"] = "Bearer #{secret_key}"
  request["Accept"] = "application/json"
  request
end

base_url = backend_api_base_url(publishable_key)
e164_phone_number = "+1#{digits}"
users_uri = base_url.dup
users_uri.path = "/v1/users"
users_uri.query = URI.encode_www_form([
  ["phone_number[]", e164_phone_number],
  ["limit", "100"],
])

users_response = perform_request(
  users_uri,
  authorized_request(Net::HTTP::Get.new(users_uri), secret_key)
)
payload = JSON.parse(users_response.body)
users = payload.is_a?(Hash) ? payload.fetch("data", []) : payload
user_ids = users.each_with_object([]) do |user, matches|
  phone_numbers = user.fetch("phone_numbers", [])
  matches << user["id"] if phone_numbers.any? { |resource| resource["phone_number"] == e164_phone_number }
end

user_ids.each do |user_id|
  delete_uri = base_url.dup
  delete_uri.path = "/v1/users/#{URI.encode_www_form_component(user_id)}"
  perform_request(
    delete_uri,
    authorized_request(Net::HTTP::Delete.new(delete_uri), secret_key)
  )
end

puts "Removed #{user_ids.count} pre-existing test user(s) for the selected approved phone number."
