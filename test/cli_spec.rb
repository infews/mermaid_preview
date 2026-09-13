# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::CLI do
  let(:diagram) { write_file("chart.mmd", "flowchart LR\n  A --> B\n") }
  let(:stylesheet) { write_file("style.css", ".node {}\n") }

  def parse(*argv) = MermaidPreview::CLI.parse(argv)

  def usage_error(*argv)
    _ { parse(*argv) }.must_raise MermaidPreview::UsageError
  end

  describe "defaults" do
    it "needs nothing but a diagram" do
      options = parse(diagram)

      _(options.theme).must_equal "default"
      _(options.background).must_equal "transparent"
      _(options.port).must_equal 0
      _(options.browser_app).must_be_nil
      _(options.open_browser?).must_equal true
      _(options.stylesheet).must_be_nil
    end
  end

  describe "the stylesheet" do
    it "can be the second positional argument" do
      _(parse(diagram, stylesheet).stylesheet).must_equal stylesheet
    end

    it "can be given with -c" do
      _(parse(diagram, "-c", stylesheet).stylesheet).must_equal stylesheet
    end

    it "is rejected twice over" do
      _(usage_error(diagram, stylesheet, "-c", stylesheet).message).must_match(/unexpected argument/)
    end
  end

  describe "options" do
    it "accepts a theme from the allowed set" do
      _(parse(diagram, "-t", "forest").theme).must_equal "forest"
    end

    it "refuses a theme outside it" do
      _(usage_error(diagram, "-t", "bogus").message).must_match(/invalid argument/)
    end

    it "parses the port as an integer" do
      _(parse(diagram, "-p", "8080").port).must_equal 8080
    end

    it "refuses a non-numeric port" do
      _(usage_error(diagram, "-p", "eighty").message).must_match(/invalid argument/)
    end

    it "takes a background colour" do
      _(parse(diagram, "-b", "white").background).must_equal "white"
    end

    it "takes a browser app" do
      _(parse(diagram, "-B", "Google Chrome").browser_app).must_equal "Google Chrome"
    end

    it "can be told not to open one" do
      _(parse(diagram, "-n").open_browser?).must_equal false
    end
  end

  describe "paths" do
    it "expands them so a later chdir cannot break them" do
      expected = [File.realpath(diagram), File.realpath(stylesheet)]

      options = Dir.chdir(tmpdir) { parse("chart.mmd", "style.css") }

      _([options.diagram, options.stylesheet]).must_equal expected
    end

    it "refuses a diagram that is not there" do
      _(usage_error("nope.mmd").message).must_equal "no such file: nope.mmd"
    end

    it "refuses a stylesheet that is not there" do
      _(usage_error(diagram, "nope.css").message).must_equal "no such file: nope.css"
    end

    it "refuses a directory" do
      _(usage_error(tmpdir).message).must_match(/no such file/)
    end
  end

  describe "failures" do
    it "shows the banner when there is no diagram" do
      _(usage_error.message).must_match(/\Ausage: mmd-preview DIAGRAM\.mmd/)
    end

    it "reports an unknown option" do
      _(usage_error(diagram, "--wat").message).must_match(/invalid option: --wat/)
    end

    it "appends the banner to a parse error" do
      _(usage_error(diagram, "--wat").message).must_match(/usage: mmd-preview/)
    end

    it "raises HelpRequested for --help, which is not a failure" do
      error = _ { parse("--help") }.must_raise MermaidPreview::HelpRequested

      _(error.message).must_match(/usage: mmd-preview/)
      _(error.message).must_match(/--no-open/)
    end

    it "does not need a valid diagram to ask for help" do
      _ { parse("nope.mmd", "--help") }.must_raise MermaidPreview::HelpRequested
    end
  end

  it "returns something nothing downstream can mutate" do
    _(parse(diagram).frozen?).must_equal true
  end
end
