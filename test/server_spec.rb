# frozen_string_literal: true

require_relative "test_helper"

require "net/http"
require "socket"
require "uri"

describe MermaidPreview::Server do
  before do
    File.write(File.join(tmpdir, "index.html"), "<!doctype html><title>mermaid preview</title>")
    File.write(File.join(tmpdir, "state.json"), '{"rev":1,"ok":true,"source":"chart.mmd"}')
    @server = MermaidPreview::Server.start(tmpdir)
  end

  after { @server.stop }

  def get(path) = Net::HTTP.get_response(URI.join(@server.url, path))

  describe "binding" do
    it "takes an ephemeral port when asked for 0" do
      _(@server.port).must_be :>, 0
    end

    it "reports the port it actually got, not the 0 it asked for" do
      _(@server.url).must_equal "http://127.0.0.1:#{@server.port}/"
    end

    it "stays on loopback" do
      _(@server.url).must_include "127.0.0.1"
    end
  end

  describe "serving the workspace" do
    it "serves the page at the root" do
      _(get("/").body).must_include "<title>mermaid preview</title>"
    end

    it "serves the state the page polls" do
      _(JSON.parse(get("state.json").body)["rev"]).must_equal 1
    end

    it "404s for anything that is not there" do
      _(get("preview.next.svg").code).must_equal "404"
    end
  end

  # The page polls; a cached or 304 response would freeze the preview.
  describe "caching" do
    it "forbids caching of the state" do
      _(get("state.json")["cache-control"]).must_equal "no-store"
    end

    it "forbids caching of the page" do
      _(get("/")["cache-control"]).must_equal "no-store"
    end

    it "forbids caching even on a 404" do
      _(get("nope.svg")["cache-control"]).must_equal "no-store"
    end

    it "does not answer a conditional request with a 304" do
      first = get("state.json")
      conditional = Net::HTTP::Get.new(URI.join(@server.url, "state.json"))
      conditional["If-Modified-Since"] = first["last-modified"]
      response = Net::HTTP.start("127.0.0.1", @server.port) { |http| http.request(conditional) }

      _(response.code).must_equal "200"
    end
  end

  describe "#stop" do
    # WEBrick closes its listener on its own thread, so give it a moment rather
    # than racing it.
    def refused?(port, within: 3)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + within
      loop do
        begin
          TCPSocket.new("127.0.0.1", port).close
        rescue Errno::ECONNREFUSED
          return true
        end
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end

    it "releases the port" do
      server = MermaidPreview::Server.start(tmpdir)
      port = server.port
      server.stop

      _(refused?(port)).must_equal true
    end
  end
end
