# frozen_string_literal: true

module MermaidPreview
  # One preview run: render once, serve, watch, and tear it all down again.
  class Session
    SIGNALS = %w[INT TERM].freeze

    def initialize(options, reporter: Reporter.new)
      @options = options
      @reporter = reporter
    end

    def run
      Mmdc.available!

      Workspace.open { |workspace| serve(workspace, renderer_for(workspace)) }
    end

    private

    def renderer_for(workspace)
      Renderer.new(options: @options, workspace: workspace, mmdc: mmdc, reporter: @reporter)
    end

    def mmdc
      Mmdc.new(theme: @options.theme, background: @options.background, stylesheet: @options.stylesheet)
    end

    # The first render happens before the server starts, so the page has
    # something to show on its very first poll.
    def serve(workspace, renderer)
      renderer.render
      server = Server.start(workspace.root, port: @options.port)
      announce(server.url)
      watcher = Watcher.watch(@options.watched_files) { renderer.render }
      await_signal
    ensure
      watcher&.stop
      server&.stop
    end

    def announce(url)
      @reporter.ready(url: url, watching: @options.watched_names)
      Browser.launch(url, app: @options.browser_app) if @options.open_browser?
    end

    # Signal handlers must stay trivial, so they just wake the main thread. The
    # previous handlers go back on the way out, so a Session leaves the process
    # as it found it and can be run more than once.
    def await_signal
      queue = Queue.new
      restore = {}
      SIGNALS.each { |signal| restore[signal] = Signal.trap(signal) { queue << signal } }
      queue.pop
    ensure
      restore&.each { |signal, handler| Signal.trap(signal, handler) }
    end
  end
end
