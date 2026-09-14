# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Workspace do
  let(:workspace) { MermaidPreview::Workspace.new(tmpdir) }

  def served(name) = File.read(File.join(tmpdir, name))

  describe ".open" do
    it "yields a workspace with the page already installed" do
      MermaidPreview::Workspace.open do |workspace|
        _(File.read(workspace.path("index.html"))).must_match(/<title>mermaid preview<\/title>/)
      end
    end

    it "removes the directory afterwards" do
      root = nil
      MermaidPreview::Workspace.open { |workspace| root = workspace.root }

      _(File.directory?(root)).must_equal false
    end

    it "removes the directory even when the block blows up" do
      root = nil
      boom = lambda do
        MermaidPreview::Workspace.open do |workspace|
          root = workspace.root
          fail "boom"
        end
      end

      _(&boom).must_raise RuntimeError
      _(File.directory?(root)).must_equal false
    end
  end

  describe "#publish" do
    it "moves the scratch render into place" do
      File.write(workspace.scratch_path, "<svg>new</svg>")
      workspace.publish(workspace.scratch_path)

      _(served("preview.svg")).must_equal "<svg>new</svg>"
      _(File.exist?(workspace.scratch_path)).must_equal false
    end

    it "replaces whatever was there before" do
      File.write(workspace.path("preview.svg"), "<svg>old</svg>")
      File.write(workspace.scratch_path, "<svg>new</svg>")
      workspace.publish(workspace.scratch_path)

      _(served("preview.svg")).must_equal "<svg>new</svg>"
    end
  end

  describe "#discard" do
    it "removes the scratch file" do
      File.write(workspace.scratch_path, "half a render")
      workspace.discard(workspace.scratch_path)

      _(File.exist?(workspace.scratch_path)).must_equal false
    end

    it "does not mind if there is nothing to remove" do
      workspace.discard(workspace.scratch_path) # must not raise
      _(File.exist?(workspace.scratch_path)).must_equal false
    end

    it "leaves the last good diagram alone" do
      File.write(workspace.path("preview.svg"), "<svg>good</svg>")
      workspace.discard(workspace.scratch_path)

      _(served("preview.svg")).must_equal "<svg>good</svg>"
    end
  end

  describe "#publish_stylesheet" do
    it "copies the user stylesheet in" do
      source = write_file("mine.css", ".node {}")
      workspace.publish_stylesheet(source)

      _(served("user.css")).must_equal ".node {}"
    end

    it "writes an empty one when there is no stylesheet, so the page link still resolves" do
      workspace.publish_stylesheet(nil)

      _(served("user.css")).must_equal ""
    end
  end

  describe "#record" do
    it "writes the state the page polls" do
      workspace.record(revision: 7, ok: true, source: "chart.mmd", error: "")

      _(JSON.parse(served("state.json"))).must_equal("rev" => 7, "ok" => true, "source" => "chart.mmd")
    end

    it "writes the error separately, so state.json stays small" do
      workspace.record(revision: 2, ok: false, source: "chart.mmd", error: "Parse error\non line 2")

      _(served("error.txt")).must_equal "Parse error\non line 2"
      _(JSON.parse(served("state.json"))["ok"]).must_equal false
    end

    it "clears a stale error on the next good render" do
      workspace.record(revision: 1, ok: false, source: "chart.mmd", error: "boom")
      workspace.record(revision: 2, ok: true, source: "chart.mmd", error: "")

      _(served("error.txt")).must_equal ""
    end
  end

  it "keeps the scratch file inside the served root but under a name the page never fetches" do
    _(File.dirname(workspace.scratch_path)).must_equal tmpdir
    _(File.basename(workspace.scratch_path)).wont_equal "preview.svg"
  end

  # The page spells these names out itself, so nothing but this test stops the
  # two halves of the contract from drifting apart.
  describe "the page template" do
    let(:template) { File.read(MermaidPreview::Workspace::TEMPLATE) }

    let(:referenced) do
      (template.scan(/fetch\(['"]([^'"]+)['"]/) + template.scan(/href=['"]([^'"]+)['"]/)).flatten.uniq
    end

    it "asks for exactly the files the workspace publishes" do
      published = [
        MermaidPreview::Workspace::DIAGRAM, MermaidPreview::Workspace::STYLESHEET,
        MermaidPreview::Workspace::STATE, MermaidPreview::Workspace::ERROR
      ]

      _(referenced.sort).must_equal published.sort
    end

    it "never asks for the scratch render" do
      _(referenced).wont_include MermaidPreview::Workspace::SCRATCH
    end

    # Stylesheets written for mermaid-in-a-browser prefix everything with
    # `.mermaid`, because that is the element mermaid.initialize() renders into.
    # mmdc's SVG has no such ancestor, so without this class every rule in such
    # a sheet misses and the diagram comes out in bare theme colours.
    it "gives the diagram the .mermaid ancestor that mermaid stylesheets are written against" do
      _(template).must_match(/<div class="stage mermaid"/)
    end

    # The link is fetched once at page load and never again, so without a
    # cache-buster tied to the revision a CSS edit never reaches an open page —
    # and worse, a rule the user has deleted keeps applying until a manual
    # reload, because the stale sheet still carries it.
    it "re-requests the stylesheet when the revision changes" do
      _(template).must_match(/\.href = ['"]#{Regexp.escape(MermaidPreview::Workspace::STYLESHEET)}\?rev=/o)
    end
  end
end
