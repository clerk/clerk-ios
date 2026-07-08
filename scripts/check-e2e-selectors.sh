#!/usr/bin/env ruby
# frozen_string_literal: true

require "set"

ROOT = File.expand_path("..", __dir__)
PRODUCT_IDENTIFIER_SOURCE = "Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift"
HOST_IDENTIFIER_SOURCE = "Examples/E2EHost/E2EHost/E2EIdentifiers.swift"
E2E_TEST_SOURCE = "Examples/E2EHost/E2EHostE2ETests/E2EHostE2ETests.swift"

NON_SELECTOR_CLERK_LITERALS = Set[
  "clerk.dev",
].freeze

VISIBLE_TEXT_SELECTOR_EXCEPTIONS = Set[
  "Cancel",
].freeze

VISIBLE_TEXT_SELECTOR_QUERIES = %w[
  alerts
  buttons
  cells
  images
  otherElements
  secureTextFields
  staticTexts
  switches
  textFields
].freeze

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

quoted_literals(E2E_TEST_SOURCE, prefix: "clerk.").each do |literal|
  next if NON_SELECTOR_CLERK_LITERALS.include?(literal.value)
  next if backed_by_contract?(literal.value, product_exact_values, product_patterns)

  failures << [
    literal.file,
    literal.line,
    "E2E product selector '#{literal.value}' is not backed by #{PRODUCT_IDENTIFIER_SOURCE}.",
  ]
end

quoted_literals(E2E_TEST_SOURCE, prefix: "e2e.").each do |literal|
  next if host_exact_values.include?(literal.value)

  failures << [
    literal.file,
    literal.line,
    "E2EHost selector '#{literal.value}' is not backed by #{HOST_IDENTIFIER_SOURCE}.",
  ]
end

source_lines(E2E_TEST_SOURCE).each_with_index do |line, index|
  line.scan(/app\.(?:#{VISIBLE_TEXT_SELECTOR_QUERIES.join("|")})\["([^"]+)"\]/).flatten.each do |visible_text|
    next if VISIBLE_TEXT_SELECTOR_EXCEPTIONS.include?(visible_text)

    failures << [
      E2E_TEST_SOURCE,
      index + 1,
      "Use an accessibility identifier instead of visible text selector '#{visible_text}', or add a reviewed exception.",
    ]
  end
end

failures.each do |file, line, message|
  report_error(file, line, message)
end

if failures.any?
  warn "E2E selector check failed with #{failures.count} issue(s)."
  exit 1
end

puts "E2E selector check passed: #{product_literals.count} product selectors, #{host_literals.count} E2EHost selectors."
