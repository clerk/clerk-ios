#!/usr/bin/env ruby
# frozen_string_literal: true

APPROVED_RANGE = 5_555_550_100..5_555_550_199
E2E_SOURCES = [
  "Examples/E2EHost",
].freeze

failure_count = 0

def report_error(file, line, message)
  if ENV["GITHUB_ACTIONS"]
    puts "::error file=#{file},line=#{line}::#{message}"
  else
    warn "error: #{file}:#{line}: #{message}"
  end
end

def normalized_phone_digits(value)
  digits = value.gsub(/\D/, "")
  digits = digits[1..] if digits.length == 11 && digits.start_with?("1")
  digits
end

Dir.glob(E2E_SOURCES.map { |source| File.join(source, "**/*.swift") }).each do |file|
  File.readlines(file, chomp: true).each_with_index do |line, index|
    line.scan(/\+?1?555555\d{4}/).each do |candidate|
      digits = normalized_phone_digits(candidate)
      next if digits.length == 10 && APPROVED_RANGE.cover?(digits.to_i)

      report_error(
        file,
        index + 1,
        "E2E phone number '#{candidate}' is outside the approved 5555550100...5555550199 test-number range."
      )
      failure_count += 1
    end
  end
end

if failure_count.positive?
  warn "E2E phone-number check failed with #{failure_count} issue(s)."
  exit 1
end

puts "E2E phone-number check passed: approved range 5555550100...5555550199."
