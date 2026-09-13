# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Mmdc do
  let(:target) { File.join(tmpdir, "out.svg") }

  def build(**overrides)
    MermaidPreview::Mmdc.new(
      theme: "default", background: "transparent", puppeteer_config: "/nope/puppeteer.json", **overrides
    )
  end

  # Renders against a stubbed Open3, recording the argv mmdc would have run.
  def render(mmdc, wrote: nil, success: true)
    stub = lambda do |*argv|
      @argv = argv
      File.write(target, wrote) if wrote
      ["mmdc output", FakeStatus.new(ok: success)]
    end

    Open3.stub(:capture2e, stub) { mmdc.render("chart.mmd", to: target) }
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

    it "adds -C when there is a stylesheet" do
      argv = argv_for(build(stylesheet: "/tmp/style.css"))

      _(argv[argv.index("-C") + 1]).must_equal "/tmp/style.css"
    end

    it "leaves -C out when there is not" do
      _(argv_for(build)).wont_include "-C"
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

  describe ".available!" do
    it "returns the path when mmdc is installed" do
      bin = mkdirs(tmpdir, "bin").first
      make_executable(bin, "mmdc")

      with_path(bin) { _(MermaidPreview::Mmdc.available!).must_equal File.join(bin, "mmdc") }
    end

    it "points at the init script when it is not" do
      error = with_path(tmpdir) do
        _ { MermaidPreview::Mmdc.available! }.must_raise MermaidPreview::MissingDependencyError
      end

      _(error.message).must_equal "mmdc not found; run mmd-preview-init"
    end
  end
end
