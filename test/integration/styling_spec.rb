# frozen_string_literal: true

require_relative "../test_helper"

# The one spec that runs the real mmdc. Every other spec stubs Open3, which is
# exactly how a correct-looking `-C` once shipped CSS that styled nothing: the
# argv was right and the cascade was wrong, and no stub can tell you that.
#
# Skipped rather than failed when mmdc or its browser is missing, so the suite
# still runs on a machine that cannot render.
describe "user styling through the real mmdc" do
  before do
    skip "mmdc or a browser for it is unavailable" unless MermaidPreview::Doctor.examine.ok?
  end

  let(:diagram) { write_file("chart.mmd", "flowchart LR\n  A[Alpha] --> B[Beta]\n") }
  let(:stylesheet) { write_file("style.css", ".node rect { stroke-width: 7px; }\n") }

  let(:svg) do
    target = File.join(tmpdir, "out.svg")
    mmdc = MermaidPreview::Mmdc.new(theme: "default", background: "transparent", stylesheet: stylesheet)
    result = mmdc.render(diagram, to: target)
    flunk "mmdc could not render: #{result.output}" unless result.ok?

    File.read(target)
  end

  # Two assertions because they are two halves of one fact: equal specificity
  # AND later position is what makes the user's rule win. Either alone loses.
  # One assertion per test would mean rendering twice, at four seconds a render.
  it "scopes the rule like the theme's own and emits it afterwards, so it wins" do
    theme_rule = svg.index(/\#my-svg \.node rect,/)   # mermaid's, a selector list
    user_rule = svg.index(/\#my-svg \.node rect\{/)   # ours, on its own

    _(user_rule).wont_be_nil "the user's rule is not scoped to the diagram id, so the theme outranks it"
    _(theme_rule).wont_be_nil "mermaid stopped scoping its theme CSS; this spec's premise needs rechecking"
    _(user_rule).must_be :>, theme_rule
  end

  it "carries the user's declaration through untouched" do
    _(svg).must_match(/\#my-svg \.node rect\{[^}]*stroke-width:\s*7px/)
  end
end
