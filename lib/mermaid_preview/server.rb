# frozen_string_literal: true

require "webrick"

module MermaidPreview
  # FileHandler is happy to serve a 304 or a cached response; the page polls for
  # changes, so every response has to be uncacheable.
  class NoCacheFiles < WEBrick::HTTPServlet::FileHandler
    def do_GET(request, response)
      super
    ensure
      response["Cache-Control"] = "no-store"
    end
  end

  # Loopback-only static server for a workspace, running on its own thread.
  class Server
    ADDRESS = "127.0.0.1"
    STARTUP_GRACE = 5
    SHUTDOWN_GRACE = 2

    def self.start(root, port: 0) = new(root, port).start

    def initialize(root, port)
      @running = Queue.new
      @server = WEBrick::HTTPServer.new(**silent_config(port))
      @server.mount("/", NoCacheFiles, root, FancyIndexing: false)
    end

    # WEBrick rewrites config[:Port] with the real one when asked for 0.
    def port = @server.config[:Port]

    def url = "http://#{ADDRESS}:#{port}/"

    # Waits for WEBrick to reach :Running. WEBrick#shutdown is a no-op until
    # then, so returning early would let a quick stop go missing and leave the
    # thread serving forever.
    def start
      @thread = Thread.new { @server.start }
      fail Error, "the preview server did not come up" if @running.pop(timeout: STARTUP_GRACE).nil?

      self
    end

    def stop
      @server.shutdown
      @thread&.join(SHUTDOWN_GRACE)
    end

    private

    def silent_config(port)
      {BindAddress: ADDRESS, Port: port, Logger: WEBrick::Log.new(File::NULL),
       AccessLog: [], DoNotReverseLookup: true, StartCallback: -> { @running << :up }}
    end
  end
end
