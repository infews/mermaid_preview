# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Mmdc do
  let(:target) { File.join(tmpdir, "out.svg") }

  def build(**overrides)
    MermaidPreview::Mmdc.new(
      theme: "default", background: "transparent", puppeteer_config: "/nope/puppeteer.json", **overrides
    )
  end

  # Renders against a stubbed Open3, recording the argv mmdc would have run and
  # the mermaid config that was on disk while it ran — the config is temporary,
  # so reading it after the fact is too late.
  def render(mmdc, wrote: nil, success: true)
    stub = lambda do |*argv|
      @argv = argv
      @config = config_during(argv)
      File.write(target, wrote) if wrote
      ["mmdc output", FakeStatus.new(ok: success)]
    end

    Open3.stub(:capture2e, stub) { mmdc.render("chart.mmd", to: target) }
  end

  def config_during(argv)
    index = argv.index("-c")
    JSON.parse(File.read(argv[index + 1])) if index
  end

  def argv_for(mmdc)
    render(mmdc, wrote: "<svg/>")
    @argv
  end

  describe "the command it builds" do
    it "passes the source, target, theme and background" do
      argv = argv_for(build(theme: "dark", background: "white"))

      _(argv).must_equal ["mmdc", "-i", "chart.mmd", "-o", target, "-t", "dark", "-b", "white"]
    end

    it "adds -p when the puppeteer config exists" do
      config = write_file("puppeteer.json", "{}")
      argv = argv_for(build(puppeteer_config: config))

      _(argv[argv.index("-p") + 1]).must_equal config
    end

    it "leaves -p out when the config is not there yet" do
      _(argv_for(build)).wont_include "-p"
    end
  end

  # mermaid scopes its theme CSS to the diagram's id (#my-svg .node rect), so a
  # plain `.node rect` rule loses on specificity however late it arrives. Handing
  # the CSS over as themeCSS makes mermaid scope the user's rules the same way
  # and emit them after its own, which is the only way they win.
  describe "the stylesheet" do
    let(:stylesheet) { write_file("style.css", ".node rect { stroke-width: 7px; }") }

    it "goes to mermaid as themeCSS" do
      render(build(stylesheet: stylesheet), wrote: "<svg/>")

      _(@config["themeCSS"]).must_equal ".node rect { stroke-width: 7px; }"
    end

    it "is not passed as -C, which mermaid leaves unscoped for the theme to outrank" do
      _(argv_for(build(stylesheet: stylesheet))).wont_include "-C"
    end

    it "is re-read every render, so edits land without a restart" do
      mmdc = build(stylesheet: stylesheet)
      render(mmdc, wrote: "<svg/>")
      File.write(stylesheet, ".node rect { stroke-width: 9px; }")
      render(mmdc, wrote: "<svg/>")

      _(@config["themeCSS"]).must_equal ".node rect { stroke-width: 9px; }"
    end

    it "sends no config at all when there is no stylesheet" do
      _(argv_for(build)).wont_include "-c"
    end

    it "leaves no config file behind" do
      argv = argv_for(build(stylesheet: stylesheet))

      _(File.exist?(argv[argv.index("-c") + 1])).must_equal false
    end
  end

  describe "the result" do
    it "is ok when mmdc succeeds and writes an SVG" do
      result = render(build, wrote: "<svg/>")

      _(result.ok?).must_equal true
      _(result.output).must_equal "mmdc output"
    end

    it "is not ok when mmdc fails" do
      _(render(build, wrote: "<svg/>", success: false).ok?).must_equal false
    end

    # mmdc can exit 0 and write nothing at all.
    it "is not ok when mmdc succeeds but writes no file" do
      _(render(build).ok?).must_equal false
    end

    it "is not ok when the file it wrote is empty" do
      _(render(build, wrote: "").ok?).must_equal false
    end

    it "carries mmdc output either way, so the page can show it" do
      _(render(build, success: false).output).must_equal "mmdc output"
    end

    # Otherwise a run that exits 0 without writing would publish the last run's
    # SVG as if it were fresh.
    it "is not ok when a stale file is sitting at the target" do
      File.write(target, "<svg>stale</svg>")

      _(render(build).ok?).must_equal false
    end

    it "clears the target before running, so a failure leaves nothing behind" do
      File.write(target, "<svg>stale</svg>")
      render(build, success: false)

      _(File.exist?(target)).must_equal false
    end
  end
end
