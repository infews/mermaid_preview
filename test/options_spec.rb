# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Options do
  def build(stylesheet: "/tmp/style.css")
    MermaidPreview::Options.new(
      diagram: "/tmp/chart.mmd", stylesheet: stylesheet, theme: "default",
      background: "transparent", port: 0, browser_app: nil, open_browser: true
    )
  end

  describe "#watched_files" do
    it "lists both files when there is a stylesheet" do
      _(build.watched_files).must_equal ["/tmp/chart.mmd", "/tmp/style.css"]
    end

    it "drops the stylesheet when there is none" do
      _(build(stylesheet: nil).watched_files).must_equal ["/tmp/chart.mmd"]
    end
  end

  describe "#watched_names" do
    it "is what the banner prints" do
      _(build.watched_names).must_equal %w[chart.mmd style.css]
    end

    it "follows watched_files when the stylesheet is absent" do
      _(build(stylesheet: nil).watched_names).must_equal %w[chart.mmd]
    end
  end

  it "answers open_browser? as a predicate" do
    _(build.open_browser?).must_equal true
  end

  it "is frozen" do
    _(build.frozen?).must_equal true
  end

  it "copies rather than mutates" do
    original = build
    variant = original.with(theme: "dark")

    _(variant.theme).must_equal "dark"
    _(original.theme).must_equal "default"
  end
end
