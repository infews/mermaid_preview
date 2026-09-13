# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Reporter do
  let(:log) { StringIO.new }
  let(:reporter) { MermaidPreview::Reporter.new(log) }

  describe "on a plain stream" do
    it "marks a render with a timestamp and no escape codes" do
      reporter.rendered

      _(log.string).must_match(/\A● \d\d:\d\d:\d\d  rendered\n\z/)
    end

    it "marks a failure the same way" do
      reporter.failed

      _(log.string).must_match(/\A● \d\d:\d\d:\d\d  render failed\n\z/)
    end

    it "never emits ANSI when the stream is not a terminal" do
      reporter.rendered
      reporter.failed

      _(log.string).wont_match(/\e\[/)
    end
  end

  describe "on a terminal" do
    let(:log) { TtyIO.new }

    it "colours a render green" do
      reporter.rendered

      _(log.string).must_match(/\e\[32m●\e\[0m/)
    end

    it "colours a failure red" do
      reporter.failed

      _(log.string).must_match(/\e\[31m●\e\[0m/)
    end
  end

  describe "#ready" do
    it "prints the URL, the watched files and how to stop" do
      reporter.ready(url: "http://127.0.0.1:8791/", watching: %w[chart.mmd style.css])

      _(log.string).must_include "http://127.0.0.1:8791/"
      _(log.string).must_include "watching chart.mmd and style.css"
      _(log.string).must_include "Ctrl-C to stop"
    end

    it "reads correctly with a single watched file" do
      reporter.ready(url: "http://127.0.0.1:8791/", watching: %w[chart.mmd])

      _(log.string).must_include "watching chart.mmd"
    end
  end

  it "defaults to stderr, so the preview URL survives a piped stdout" do
    original = $stderr
    $stderr = StringIO.new
    MermaidPreview::Reporter.new.rendered

    _($stderr.string).must_match(/rendered/)
  ensure
    $stderr = original
  end
end
