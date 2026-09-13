# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Browser do
  let(:url) { "http://127.0.0.1:8791/" }

  # Runs launch with a pretend PATH and a pretend `system`, returning both what
  # launch answered and the command it would have run.
  def launch(app: nil, available: [])
    command = nil
    on_path = ->(name) { available.include?(name) }
    record = ->(*argv) {
      command = argv
      true
    }

    answer = MermaidPreview::Executable.stub(:exist?, on_path) do
      MermaidPreview::Browser.stub(:silently, record) do
        MermaidPreview::Browser.launch(url, app: app)
      end
    end

    [answer, command]
  end

  it "asks a named app to open the URL" do
    _, command = launch(app: "Google Chrome", available: %w[open])

    _(command).must_equal ["open", "-a", "Google Chrome", url]
  end

  it "uses open on macOS" do
    _, command = launch(available: %w[open])

    _(command).must_equal ["open", url]
  end

  it "falls back to xdg-open elsewhere" do
    _, command = launch(available: %w[xdg-open])

    _(command).must_equal ["xdg-open", url]
  end

  it "prefers open when both are there" do
    _, command = launch(available: %w[open xdg-open])

    _(command).must_equal ["open", url]
  end

  describe "on a machine with no opener" do
    it "runs nothing" do
      _, command = launch(available: [])

      _(command).must_be_nil
    end

    # The URL has already been printed, so this is a shrug, not a failure.
    it "reports that it did not open anything" do
      answer, = launch(available: [])

      _(answer).must_equal false
    end
  end

  it "trusts a named app without checking PATH first" do
    _, command = launch(app: "Safari", available: [])

    _(command).must_equal ["open", "-a", "Safari", url]
  end
end
