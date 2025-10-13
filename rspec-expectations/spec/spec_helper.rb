# frozen_string_literal: true

require 'rspec/support/spec'
require 'rspec/support/spec/in_sub_process'

RSpec::Support::Spec::Coverage.setup do
  minimum_coverage 100
end

Dir['./spec/support/**/*.rb'].each do |f|
  require f.sub(%r{\./spec/}, '')
end

module CommonHelperMethods
  def with_env_vars(vars)
    original = ENV.to_hash
    vars.each { |k, v| ENV[k] = v }

    begin
      yield
    ensure
      ENV.replace(original)
    end
  end

  def dedent(string)
    string.gsub(/^\s+\|/, '').chomp
  end

  def capture_warnings(&block)
    warning_notifier = RSpec::Support.warning_notifier
    warnings = []
    RSpec::Support.warning_notifier = lambda { |warning| warnings << warning }

    begin
      block.call
    ensure
      RSpec::Support.warning_notifier = warning_notifier
    end

    warnings
  end

  def hash_inspect(hash)
    RSpec::Matchers::BuiltIn::BaseMatcher::HashFormatting.
      improve_hash_formatting hash.inspect
  end
end

RSpec.configure do |config|
  config.order = :random

  config.include CommonHelperMethods
  config.include RSpec::Support::InSubProcess

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # We don't want rspec-core to look in our `lib` for failure snippets.
  # When it does that, it inevitably finds this line:
  # `RSpec::Support.notify_failure(RSpec::Expectations::ExpectationNotMetError.new message)`
  # ...which isn't very helpful. Far better for it to find the expectation
  # call site in the spec.
  config.project_source_dirs -= ["lib"]
end

RSpec.shared_context "with on_potential_false_positives set to nothing" do
  original_value = RSpec::Expectations.configuration.on_potential_false_positives

  after(:context)  { RSpec::Expectations.configuration.on_potential_false_positives = original_value }
end

RSpec.configuration.include_context "with on_potential_false_positives set to nothing", :potential_false_positives

RSpec.shared_context "with modified configuration" do
  around do |example|
    configuration = example.metadata[:with_configuration]
    original = configuration.keys.each.with_object({}) do |key, config|
      config[key] = RSpec::Expectations.configuration.public_send(key)
    end
    configuration.each do |key, value|
      RSpec::Expectations.configuration.public_send("#{key}=", value)
    end
    example.run
    original.each do |key, value|
      RSpec::Expectations.configuration.public_send("#{key}=", value)
    end
  end
end
RSpec.configuration.include_context "with modified configuration", :with_configuration

module MinitestIntegration
  include ::RSpec::Support::InSubProcess

  def with_minitest_loaded
    in_sub_process do
      with_isolated_stderr do
        require 'minitest/autorun'
      end

      require 'rspec/expectations/minitest_integration'
      yield
    end
  end
end

RSpec::Matchers.define_negated_matcher :avoid_outputting, :output
