#!/usr/bin/env ruby
# frozen_string_literal: true

require "set"

ROOT = File.expand_path("..", __dir__)
PRODUCT_IDENTIFIER_SOURCE = "Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift"
HOST_IDENTIFIER_SOURCE = "Examples/E2EHost/E2EHost/E2EIdentifiers.swift"
MAESTRO_FLOW_GLOB = "Examples/E2EHost/Maestro/**/*.{yaml,yml}"

SelectorLiteral = Struct.new(:value, :file, :line, keyword_init: true)

def source_lines(relative_path)
  File.readlines(File.join(ROOT, relative_path), chomp: true)
end

def quoted_literals(relative_path, prefix:)
  source_lines(relative_path).each_with_index.flat_map do |line, index|
    line.scan(/"((?:\\.|[^"\\])*)"/).flatten.select { |value| value.start_with?(prefix) }.map do |value|
      SelectorLiteral.new(value: value, file: relative_path, line: index + 1)
    end
  end
end

def literal_pattern(value)
  pieces = value.split(/\\\([^)]*\)/, -1)
  Regexp.new("\\A#{pieces.map { |piece| Regexp.escape(piece) }.join(".+")}\\z")
end

def backed_by_contract?(value, exact_values, patterns)
  exact_values.include?(value) || patterns.any? { |pattern| pattern.match?(value) }
end

def report_error(file, line, message)
  if ENV["GITHUB_ACTIONS"]
    puts "::error file=#{file},line=#{line}::#{message}"
  else
    warn "error: #{file}:#{line}: #{message}"
  end
end

product_literals = quoted_literals(PRODUCT_IDENTIFIER_SOURCE, prefix: "clerk.")
product_exact_values = product_literals.map(&:value).to_set
product_patterns = product_literals.map { |literal| literal_pattern(literal.value) }

host_literals = quoted_literals(HOST_IDENTIFIER_SOURCE, prefix: "e2e.")
host_exact_values = host_literals.map(&:value).to_set

failures = []
maestro_selector_count = 0

Dir.glob(File.join(ROOT, MAESTRO_FLOW_GLOB)).sort.each do |absolute_path|
  relative_path = absolute_path.delete_prefix("#{ROOT}/")

  File.readlines(absolute_path, chomp: true).each_with_index do |line, index|
    line.scan(/\bid:\s*(?:['"]([^'"]+)['"]|([^\s#]+))/).each do |quoted_value, plain_value|
      value = quoted_value || plain_value
      maestro_selector_count += 1

      if value.start_with?("clerk.")
        next if backed_by_contract?(value, product_exact_values, product_patterns)

        failures << [
          relative_path,
          index + 1,
          "Maestro product selector '#{value}' is not backed by #{PRODUCT_IDENTIFIER_SOURCE}.",
        ]
      elsif value.start_with?("e2e.")
        next if host_exact_values.include?(value)

        failures << [
          relative_path,
          index + 1,
          "Maestro E2EHost selector '#{value}' is not backed by #{HOST_IDENTIFIER_SOURCE}.",
        ]
      end
    end
  end
end

failures.each do |file, line, message|
  report_error(file, line, message)
end

if failures.any?
  warn "E2E selector check failed with #{failures.count} issue(s)."
  exit 1
end

puts "E2E selector check passed: #{product_literals.count} product selectors, #{host_literals.count} E2EHost selectors, #{maestro_selector_count} Maestro selector usages."
