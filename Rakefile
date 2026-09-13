# frozen_string_literal: true

require "rake/testtask"
require "standard/rake"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/**/*_spec.rb"
  t.warning = true
end

task default: %i[standard:fix test]
