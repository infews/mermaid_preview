# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

module MermaidPreview
  # The directory WEBrick serves. These constants are the Ruby half of the
  # contract with the browser; the other half is spelled out again in the
  # fetch() and href= of templates/index.html, which a static page has no way to
  # read from here. workspace_spec holds the two halves together — change a name
  # here and the template test fails until the page agrees.
  class Workspace
    PAGE = "index.html"
    DIAGRAM = "preview.svg"
    SCRATCH = "preview.next.svg"
    STYLESHEET = "user.css"
    STATE = "state.json"
    ERROR = "error.txt"

    TEMPLATE = File.expand_path("templates/index.html", __dir__)

    # Block form only: the temp dir goes away however the block exits.
    def self.open
      Dir.mktmpdir("mmd-preview") do |dir|
        workspace = new(dir)
        workspace.install_page
        yield workspace
      end
    end

    attr_reader :root

    def initialize(root) = @root = root

    def install_page = FileUtils.cp(TEMPLATE, path(PAGE))

    def path(name) = File.join(@root, name)

    def scratch_path = path(SCRATCH)

    # Rename within the same dir is atomic, so the page can never fetch a
    # half-written SVG.
    def publish(scratch) = FileUtils.mv(scratch, path(DIAGRAM))

    def discard(scratch) = FileUtils.rm_f(scratch)

    # The page links the stylesheet too, so `body`/`.canvas` rules style the
    # frame. Copied rather than symlinked so WEBrick never has to follow a link
    # out of its document root.
    def publish_stylesheet(source)
      source ? FileUtils.cp(source, path(STYLESHEET)) : FileUtils.touch(path(STYLESHEET))
    end

    # The revision is what the page polls on; the rest is what it displays.
    def record(revision:, ok:, source:, error:)
      File.write(path(ERROR), error)
      File.write(path(STATE), JSON.generate(rev: revision, ok: ok, source: source))
    end
  end
end
