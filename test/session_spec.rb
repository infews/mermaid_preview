# frozen_string_literal: true

require_relative "test_helper"

require "net/http"
require "socket"
require "uri"

describe MermaidPreview::Session do
  let(:diagram) { write_file("chart.mmd", "flowchart LR\n  A --> B\n") }

  def session_for(log)
    options = MermaidPreview::Options.new(
      diagram: diagram, stylesheet: nil, theme: "default", background: "transparent",
      port: 0, browser_app: nil, open_browser: false
    )
    MermaidPreview::Session.new(options, reporter: MermaidPreview::Reporter.new(log))
  end

  describe "before it starts" do
    it "refuses to start when mmdc is not installed" do
      error = with_path(tmpdir) do
        _ { session_for(StringIO.new).run }.must_raise MermaidPreview::MissingDependencyError
      end

      _(error.message).must_equal "mmdc not found; run mmd-preview-init"
    end

    it "checks for mmdc before it creates a workspace" do
      opened = false

      MermaidPreview::Workspace.stub(:open, ->(*) { opened = true }) do
        with_path(tmpdir) do
          _ { session_for(StringIO.new).run }.must_raise MermaidPreview::MissingDependencyError
        end
      end

      _(opened).must_equal false
    end
  end

  # A real run, end to end, against a stub mmdc and wound up by a real signal.
  describe "a full run" do
    let(:log) { StringIO.new }

    # Answers -o with a fixed SVG and ignores every other argument.
    def stub_mmdc
      bin = mkdirs(tmpdir, "bin").first
      script = File.join(bin, "mmdc")
      File.write(script, <<~SH)
        #!/bin/sh
        while [ $# -gt 0 ]; do
          if [ "$1" = "-o" ]; then shift; printf '<svg id="stub"/>' > "$1"; fi
          shift
        done
      SH
      FileUtils.chmod(0o755, script)
      bin
    end

    def port_from_log = log.string[%r{http://127\.0\.0\.1:(\d+)/}, 1].to_i

    def until_deadline(what, within: 20)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + within
      loop do
        result = yield
        return result if result
        raise "session #{what}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end

    # Runs a session on its own thread, hands the serving port to the block, then
    # interrupts until it winds up. Interrupting repeatedly is deliberate: a
    # signal sent before the session installs its handler lands on the sentinel
    # below and would otherwise be lost.
    def run_session
      thread = Thread.new { session_for(log).run }
      port = until_deadline("never announced a port") { port_from_log.positive? && port_from_log }
      yield port if block_given?
      port
    ensure
      until_deadline("never shut down") { Process.kill("INT", Process.pid) && thread.join(0.2) }
    end

    # Keeps a handler installed throughout, so an interrupt can never reach the
    # default one and take the whole test run down with it.
    def under_sentinel
      sentinel = proc { :ignored }
      previous = MermaidPreview::Session::SIGNALS.to_h { |sig| [sig, Signal.trap(sig, sentinel)] }
      yield sentinel
    ensure
      previous.each { |sig, handler| Signal.trap(sig, handler) }
    end

    it "puts the signal handlers back the way it found them" do
      under_sentinel do |sentinel|
        with_path(stub_mmdc) { run_session }

        MermaidPreview::Session::SIGNALS.each do |signal|
          _(Signal.trap(signal, sentinel)).must_be_same_as sentinel
        end
      end
    end

    it "serves the rendered diagram while it runs" do
      served = nil

      under_sentinel do
        with_path(stub_mmdc) do
          run_session { |port| served = Net::HTTP.get(URI("http://127.0.0.1:#{port}/preview.svg")) }
        end
      end

      _(served).must_equal '<svg id="stub"/>'
    end

    it "releases the port on the way out" do
      port = under_sentinel { with_path(stub_mmdc) { run_session } }

      _ { TCPSocket.new("127.0.0.1", port).close }.must_raise Errno::ECONNREFUSED
    end

    it "reports the URL, the watched file and the first render" do
      under_sentinel { with_path(stub_mmdc) { run_session } }

      _(log.string).must_match(%r{http://127\.0\.0\.1:\d+/})
      _(log.string).must_include "watching chart.mmd"
      _(log.string).must_match(/rendered/)
    end
  end
end
