# frozen_string_literal: true

module MermaidPreview
  THEMES = %w[default forest dark neutral].freeze

  # The parsed command line. Immutable: CLI does all the validating and
  # expanding, everything downstream only reads. Paths are absolute by the time
  # they get here.
  Options = Data.define(
    :diagram, :stylesheet, :theme, :background, :port, :browser_app, :open_browser
  ) do
    def open_browser? = open_browser

    def watched_files = [diagram, stylesheet].compact

    def watched_names = watched_files.map { File.basename(it) }
  end
end
