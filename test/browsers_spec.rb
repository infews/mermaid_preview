# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Browsers do
  let(:browsers) { MermaidPreview::Browsers }

  describe ".installed" do
    it "returns the first candidate that is executable" do
      first = make_executable(tmpdir, "Chromium")
      second = make_executable(tmpdir, "Google Chrome")

      _(browsers.installed([first, second])).must_equal first
    end

    it "walks past candidates that are not there" do
      real = make_executable(tmpdir, "Google Chrome")

      _(browsers.installed(["/nope/Chromium", real])).must_equal real
    end

    it "ignores a candidate that is not executable" do
      File.write(File.join(tmpdir, "Chromium"), "")

      _(browsers.installed([File.join(tmpdir, "Chromium")])).must_be_nil
    end

    it "returns nil when there is no browser anywhere" do
      _(browsers.installed(["/nope/Chromium", "/also/nope"])).must_be_nil
    end

    it "expands ~ in the candidate list" do
      _(browsers.installed(["~/definitely-not-a-browser"])).must_be_nil
    end

    it "looks in the usual desktop places by default" do
      _(MermaidPreview::Browsers::CANDIDATES).must_include "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" # standard:disable Layout/LineLength
    end
  end

  describe ".cached" do
    def cache_with(*relative_paths)
      relative_paths.each do |relative|
        full = File.join(tmpdir, "cache", relative)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, "")
        FileUtils.chmod(0o755, full)
      end
      File.join(tmpdir, "cache")
    end

    it "finds a browser puppeteer downloaded" do
      cache = cache_with("chrome/mac-131/chrome-mac/Google Chrome for Testing")

      with_env({"PUPPETEER_CACHE_DIR" => cache}) do
        _(browsers.cached).must_equal File.join(cache, "chrome/mac-131/chrome-mac/Google Chrome for Testing")
      end
    end

    it "prefers the newest when several are cached" do
      cache = cache_with("chrome/mac-120/chrome", "chrome/mac-131/chrome")

      with_env({"PUPPETEER_CACHE_DIR" => cache}) do
        _(browsers.cached).must_include "mac-131"
      end
    end

    it "ignores files that are not browsers" do
      cache = cache_with("chrome/mac-131/README.md")

      with_env({"PUPPETEER_CACHE_DIR" => cache}) { _(browsers.cached).must_be_nil }
    end

    it "is nil when the cache is empty" do
      with_env({"PUPPETEER_CACHE_DIR" => File.join(tmpdir, "empty")}) { _(browsers.cached).must_be_nil }
    end
  end

  describe ".cache_dir" do
    it "honours PUPPETEER_CACHE_DIR" do
      with_env({"PUPPETEER_CACHE_DIR" => "/somewhere"}) { _(browsers.cache_dir).must_equal "/somewhere" }
    end

    it "falls back to puppeteer's default" do
      with_env({"PUPPETEER_CACHE_DIR" => nil}) do
        _(browsers.cache_dir).must_equal File.join(Dir.home, ".cache/puppeteer")
      end
    end
  end
end
