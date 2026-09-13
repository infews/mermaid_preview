# frozen_string_literal: true

source "https://rubygems.org"

# Left the stdlib in Ruby 3.0, so it has to be declared explicitly now.
gem "webrick", "~> 1.8"

# Replaces the fswatch dependency: FSEvents on macOS, inotify on Linux, and a
# polling fallback everywhere else, all behind one API.
gem "listen", "~> 3.9"

group :test do
  gem "minitest", "~> 5.25"
  gem "rake", "~> 13.2"
  gem "standard", "~> 1.50"
end
