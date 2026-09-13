# frozen_string_literal: true

require_relative "test_helper"

# Listen itself is not exercised here — these cover the content fingerprint on
# top of it, which is what turns filesystem noise into exactly one render.
describe MermaidPreview::Watcher do
  let(:diagram) { write_file("chart.mmd", "flowchart LR\n  A --> B\n") }
  let(:stylesheet) { write_file("style.css", ".node {}") }

  def counting_watcher(*paths)
    fired = []
    watcher = MermaidPreview::Watcher.new(paths) { fired << :change }
    [watcher, fired]
  end

  it "stays quiet when nothing has changed" do
    watcher, fired = counting_watcher(diagram)
    3.times { watcher.poll }

    _(fired).must_be_empty
  end

  it "stays quiet when a file is rewritten with identical bytes" do
    watcher, fired = counting_watcher(diagram)
    File.write(diagram, File.read(diagram))
    watcher.poll

    _(fired).must_be_empty
  end

  it "fires when the diagram changes" do
    watcher, fired = counting_watcher(diagram)
    File.write(diagram, "flowchart LR\n  A --> C\n")
    watcher.poll

    _(fired.size).must_equal 1
  end

  it "fires when the stylesheet changes" do
    watcher, fired = counting_watcher(diagram, stylesheet)
    File.write(stylesheet, ".node { fill: red; }")
    watcher.poll

    _(fired.size).must_equal 1
  end

  it "fires once per change, not once per poll" do
    watcher, fired = counting_watcher(diagram)
    File.write(diagram, "changed")
    3.times { watcher.poll }

    _(fired.size).must_equal 1
  end

  it "fires again on the next change" do
    watcher, fired = counting_watcher(diagram)
    File.write(diagram, "one")
    watcher.poll
    File.write(diagram, "two")
    watcher.poll

    _(fired.size).must_equal 2
  end

  # An editor that saves by rename briefly unlinks the file; that is a change
  # the fingerprint moves through, not a crash.
  it "treats a vanished file as a change rather than raising" do
    watcher, fired = counting_watcher(diagram)
    FileUtils.rm(diagram)
    watcher.poll

    _(fired.size).must_equal 1
  end

  it "fires again when the file comes back" do
    watcher, fired = counting_watcher(diagram)
    contents = File.read(diagram)
    FileUtils.rm(diagram)
    watcher.poll
    File.write(diagram, contents)
    watcher.poll

    _(fired.size).must_equal 2
  end

  it "ignores a nil path, so a missing stylesheet is not a special case" do
    watcher, fired = counting_watcher(diagram, nil)
    File.write(diagram, "changed")
    watcher.poll

    _(fired.size).must_equal 1
  end

  it "distinguishes the two watched files rather than hashing their union" do
    watcher, fired = counting_watcher(diagram, stylesheet)
    swapped = [File.read(stylesheet), File.read(diagram)]
    File.write(diagram, swapped.first)
    File.write(stylesheet, swapped.last)
    watcher.poll

    _(fired.size).must_equal 1
  end

  it "does not mind being stopped before it was started" do
    watcher, = counting_watcher(diagram)

    _(watcher.stop).must_be_nil
  end
end
