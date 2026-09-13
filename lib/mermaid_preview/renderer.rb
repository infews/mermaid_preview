# frozen_string_literal: true

module MermaidPreview
  # Drives mmdc and keeps the workspace's published state in step with it.
  # Renders are serialised, so a burst of saves can only ever have one mmdc run
  # in flight and the revision counter stays monotonic.
  class Renderer
    def initialize(options:, workspace:, mmdc:, reporter:)
      @options = options
      @workspace = workspace
      @mmdc = mmdc
      @reporter = reporter
      @revision = 0
      @mutex = Mutex.new
    end

    def render = @mutex.synchronize { attempt }

    private

    def attempt
      scratch = @workspace.scratch_path
      result = @mmdc.render(@options.diagram, to: scratch)

      result.ok? ? accept(scratch) : reject(scratch, result.output)
    end

    def accept(scratch)
      @workspace.publish(scratch)
      @workspace.publish_stylesheet(@options.stylesheet)
      record(ok: true, error: "")
      @reporter.rendered
    end

    # The last good diagram stays up; the page greys it out and shows the error.
    def reject(scratch, output)
      @workspace.discard(scratch)
      record(ok: false, error: output)
      @reporter.failed
    end

    def record(ok:, error:)
      @revision += 1
      @workspace.record(revision: @revision, ok: ok, source: File.basename(@options.diagram), error: error)
    end
  end
end
