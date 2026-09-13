# frozen_string_literal: true

module MermaidPreview
  # Hands a URL to the desktop. A machine with no opener is not an error — the
  # URL has already been printed.
  module Browser
    OPENERS = %w[open xdg-open].freeze

    module_function

    def launch(url, app: nil)
      return silently("open", "-a", app, url) if app

      opener = OPENERS.find { Executable.exist?(it) }
      opener ? silently(opener, url) : false
    end

    def silently(*argv) = system(*argv, out: File::NULL, err: File::NULL)
  end
end
