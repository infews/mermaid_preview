# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Doctor do
  # Examines a machine with nothing on it, unless a test says otherwise. Every
  # source the Doctor consults is redirected somewhere disposable, so the real
  # machine underneath cannot change the answer.
  def examine(mmdc: false, config: false, env_path: nil, cached: false, installed: nil)
    bin = mkdirs(tmpdir, "bin").first
    make_executable(bin, "mmdc") if mmdc
    write_puppeteer_config if config

    env = {"PATH" => bin, "XDG_CONFIG_HOME" => File.join(tmpdir, "config"),
           "PUPPETEER_EXECUTABLE_PATH" => env_path,
           "PUPPETEER_CACHE_DIR" => cached ? fill_cache : File.join(tmpdir, "bare")}

    MermaidPreview::Browsers.stub(:installed, installed) { with_env(env) { MermaidPreview::Doctor.examine } }
  end

  def write_puppeteer_config
    dir = File.join(tmpdir, "config", "mmd-preview")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "puppeteer.json"), "{}")
  end

  def fill_cache
    make_executable(mkdirs(tmpdir, "cache/chrome/mac-131").first, "Google Chrome for Testing")
    File.join(tmpdir, "cache")
  end

  let(:chrome) { "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" }

  describe "a machine that is ready" do
    it "is ok when mmdc is installed and a browser is configured" do
      _(examine(mmdc: true, config: true).ok?).must_equal true
    end

    it "accepts a browser reached through PUPPETEER_EXECUTABLE_PATH" do
      browser = make_executable(tmpdir, "chrome")

      _(examine(mmdc: true, env_path: browser).ok?).must_equal true
    end

    it "accepts a browser puppeteer downloaded for itself" do
      _(examine(mmdc: true, cached: true).ok?).must_equal true
    end

    it "does not count a browser that is merely installed" do
      _(examine(mmdc: true, installed: chrome).ok?).must_equal false
    end
  end

  describe "when mmdc is missing" do
    let(:report) { examine(config: true).to_s }

    it "is not ok" do
      _(examine(config: true).ok?).must_equal false
    end

    it "says where it looked" do
      _(report).must_include "not found on PATH"
    end

    it "suggests how to install it" do
      _(report).must_include "brew install mermaid-cli"
      _(report).must_include "npm install -g @mermaid-js/mermaid-cli"
    end

    it "still reports on the browser" do
      _(report).must_include "browser"
    end
  end

  # The common case: a perfectly good browser is right there and mmdc cannot
  # see it. The report has to be copy-pasteable, not descriptive.
  describe "when a browser is installed but unreachable" do
    let(:report) { examine(mmdc: true, installed: chrome).to_s }

    it "names the browser it found" do
      _(report).must_include "Google Chrome is installed, but mmdc can't see it."
    end

    it "names the file to create" do
      _(report).must_include "mmd-preview/puppeteer.json"
    end

    it "hands over the finished JSON with the real path filled in" do
      _(report).must_include %("executablePath": "#{chrome}")
      _(report).must_include %("headless": "new")
      _(report).must_include "--font-render-hinting=none"
    end

    it "offers the puppeteer download as an alternative" do
      _(report).must_include "npx -y puppeteer browsers install chrome"
    end

    it "does not write the config it is describing" do
      examine(mmdc: true, installed: chrome).to_s

      _(File.exist?(File.join(tmpdir, "config/mmd-preview/puppeteer.json"))).must_equal false
    end
  end

  describe "when there is no browser at all" do
    let(:report) { examine(mmdc: true).to_s }

    it "says so" do
      _(report).must_include "No Chrome or Chromium found."
    end

    it "suggests installing one or letting puppeteer fetch it" do
      _(report).must_include "Install Google Chrome"
      _(report).must_include "npx -y puppeteer browsers install chrome"
    end

    it "does not offer a config file for a browser that is not there" do
      _(report).wont_include "executablePath"
    end
  end

  describe "the report" do
    it "leads with a heading" do
      _(examine.to_s).must_match(/\Ammd-preview: unmet dependencies\n/)
    end

    it "ticks what is fine and crosses what is not" do
      report = examine(mmdc: true, installed: chrome).to_s

      _(report).must_match(/✓ mmdc/)
      _(report).must_match(/✗ browser/)
    end

    it "lists both problems when both are missing" do
      report = examine.to_s

      _(report).must_match(/✗ mmdc/)
      _(report).must_match(/✗ browser/)
    end

    it "carries no ANSI, since half of it gets copied into a file" do
      _(examine.to_s).wont_match(/\e\[/)
    end

    it "indents the remedy under the finding it belongs to" do
      _(examine(config: true).to_s).must_include "\n#{" " * 16}brew install mermaid-cli"
    end
  end
end
