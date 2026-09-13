# frozen_string_literal: true

require "digest"
require "listen"

module MermaidPreview
  # Listen gives native FSEvents on macOS. The content fingerprint on top of it
  # means unrelated writes in the watched directories are ignored, and an editor
  # that saves by rename still produces exactly one render.
  class Watcher
    LATENCY = 0.25

    def self.watch(paths, &) = new(paths, &).start

    def initialize(paths, &on_change)
      @paths = paths.compact
      @on_change = on_change
      @fingerprint = fingerprint
    end

    def start
      @listener = Listen.to(*directories, latency: LATENCY) { poll }
      @listener.start
      self
    end

    def stop = @listener&.stop

    # Fire the callback if — and only if — the watched bytes actually moved.
    def poll
      current = fingerprint
      return if current == @fingerprint

      @fingerprint = current
      @on_change.call
    end

    private

    def directories = @paths.map { File.dirname(it) }.uniq

    def fingerprint
      @paths.each_with_object(Digest::SHA256.new) { |path, sha| sha << contents(path) }.hexdigest
    end

    # Mid-save the file can be missing or unreadable; that's just a state the
    # fingerprint moves through.
    def contents(path)
      File.binread(path)
    rescue SystemCallError
      ""
    end
  end
end
