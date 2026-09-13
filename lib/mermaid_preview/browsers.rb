# frozen_string_literal: true

module MermaidPreview
  # Where a headless browser might be found. mermaid-cli bundles puppeteer-core,
  # which ships no browser and no downloader, so a browser on the desktop is
  # useless to mmdc until something points it there — which is why `installed`
  # and `cached` are separate questions.
  module Browsers
    # Checked in order; the first executable one wins.
    CANDIDATES = [
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
      "~/Applications/Chromium.app/Contents/MacOS/Chromium",
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "~/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
      "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
    ].freeze

    # What puppeteer calls the browsers it downloads for itself.
    CACHED_NAMES = ["Google Chrome for Testing", "chrome", "Chromium"].freeze

    module_function

    # A browser sitting on the desktop. mmdc cannot use this on its own.
    def installed(candidates = CANDIDATES)
      candidates.lazy.map { File.expand_path(it) }.find { File.executable?(it) }
    end

    # A browser puppeteer downloaded. mmdc finds these by itself, no config
    # needed. Newest wins, which is what sorting these paths amounts to.
    def cached
      Dir.glob(File.join(cache_dir, "**", "*")).select { runnable_browser?(it) }.max
    end

    def cache_dir = ENV["PUPPETEER_CACHE_DIR"] || File.join(Dir.home, ".cache/puppeteer")

    def runnable_browser?(path)
      CACHED_NAMES.include?(File.basename(path)) && File.file?(path) && File.executable?(path)
    end
  end
end
