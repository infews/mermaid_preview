# frozen_string_literal: true

require_relative "test_helper"

# Hands back a canned result per call and writes the scratch SVG when it says it
# succeeded, the way the real mmdc would.
class FakeMmdc
  attr_reader :calls

  def initialize(*results)
    @results = results
    @calls = []
  end

  def render(source, to:)
    @calls << [source, to]
    result = @results.shift
    File.write(to, "<svg>#{@calls.size}</svg>") if result.ok?
    result
  end
end

describe MermaidPreview::Renderer do
  def ok = MermaidPreview::Mmdc::Result.new(ok: true, output: "")
  def boom(output = "Parse error on line 2") = MermaidPreview::Mmdc::Result.new(ok: false, output: output)

  let(:log) { StringIO.new }
  let(:workspace) { MermaidPreview::Workspace.new(tmpdir) }
  let(:diagram) { write_file("chart.mmd", "flowchart LR\n  A --> B\n") }
  let(:stylesheet) { write_file("style.css", ".node {}") }

  def options(**overrides)
    MermaidPreview::Options.new(
      diagram: diagram, stylesheet: stylesheet, theme: "default", background: "transparent",
      port: 0, browser_app: nil, open_browser: false, **overrides
    )
  end

  def renderer_for(mmdc, **option_overrides)
    MermaidPreview::Renderer.new(
      options: options(**option_overrides), workspace: workspace,
      mmdc: mmdc, reporter: MermaidPreview::Reporter.new(log)
    )
  end

  def state = JSON.parse(File.read(File.join(tmpdir, "state.json")))

  def served(name) = File.read(File.join(tmpdir, name))

  describe "a successful render" do
    before { renderer_for(FakeMmdc.new(ok)).render }

    it "publishes the diagram" do
      _(served("preview.svg")).must_equal "<svg>1</svg>"
    end

    it "publishes the stylesheet alongside it" do
      _(served("user.css")).must_equal ".node {}"
    end

    it "records revision 1" do
      _(state).must_equal("rev" => 1, "ok" => true, "source" => "chart.mmd")
    end

    it "leaves no error behind" do
      _(served("error.txt")).must_equal ""
    end

    it "says so on the log" do
      _(log.string).must_match(/rendered$/)
    end
  end

  describe "a failed render" do
    it "keeps the last good diagram up" do
      renderer = renderer_for(FakeMmdc.new(ok, boom))
      renderer.render
      renderer.render

      _(served("preview.svg")).must_equal "<svg>1</svg>"
    end

    it "still bumps the revision, so the page notices" do
      renderer = renderer_for(FakeMmdc.new(ok, boom))
      renderer.render
      renderer.render

      _(state).must_equal("rev" => 2, "ok" => false, "source" => "chart.mmd")
    end

    it "writes the mmdc output for the page to show" do
      renderer_for(FakeMmdc.new(boom("Parse error\non line 2"))).render

      _(served("error.txt")).must_equal "Parse error\non line 2"
    end

    it "does not leave the scratch file where WEBrick could serve it" do
      renderer_for(FakeMmdc.new(boom)).render

      _(File.exist?(workspace.scratch_path)).must_equal false
    end

    it "says so on the log" do
      renderer_for(FakeMmdc.new(boom)).render

      _(log.string).must_match(/render failed$/)
    end
  end

  it "recovers on the next good render" do
    renderer = renderer_for(FakeMmdc.new(ok, boom, ok))
    3.times { renderer.render }

    _(state).must_equal("rev" => 3, "ok" => true, "source" => "chart.mmd")
    _(served("preview.svg")).must_equal "<svg>3</svg>"
    _(served("error.txt")).must_equal ""
  end

  it "renders into the scratch path, never straight over the live diagram" do
    mmdc = FakeMmdc.new(ok)
    renderer_for(mmdc).render

    _(mmdc.calls).must_equal [[diagram, workspace.scratch_path]]
  end

  it "touches an empty stylesheet when there is none, so the page link resolves" do
    renderer_for(FakeMmdc.new(ok), stylesheet: nil).render

    _(served("user.css")).must_equal ""
  end

  it "serialises concurrent renders" do
    renderer = renderer_for(FakeMmdc.new(*Array.new(8) { ok }))
    Array.new(8) { Thread.new { renderer.render } }.each(&:join)

    _(state["rev"]).must_equal 8
  end
end
