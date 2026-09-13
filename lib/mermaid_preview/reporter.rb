# frozen_string_literal: true

module MermaidPreview
  # Everything this tool prints. Colour only when stderr is a terminal, so a
  # redirected log stays readable.
  class Reporter
    GREEN = 32
    RED = 31

    def initialize(io = $stderr)
      @io = io
      @ansi = io.respond_to?(:tty?) && io.tty?
    end

    def rendered = event("rendered", GREEN)

    def failed = event("render failed", RED)

    def ready(url:, watching:)
      @io.puts("\n  #{url}\n  watching #{watching.join(" and ")}\n  Ctrl-C to stop\n\n")
    end

    private

    def event(message, colour)
      @io.puts("#{dot(colour)} #{Time.now.strftime("%H:%M:%S")}  #{message}")
    end

    def dot(colour) = @ansi ? "\e[#{colour}m●\e[0m" : "●"
  end
end
