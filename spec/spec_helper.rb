# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  track_files "lib/**/*.rb"
  add_filter "/spec/"
  add_filter "/vendor/"
end

SimpleCov.at_exit do
  SimpleCov.result.format!
  File.write(
    File.expand_path("../coverage/total-coverage.txt", __dir__),
    "#{SimpleCov.result.covered_percent.round(2)}%"
  )
end

require "chef_arm"
