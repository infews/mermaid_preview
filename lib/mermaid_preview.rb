# frozen_string_literal: true

# Live browser preview of a Mermaid diagram with your own CSS.
#
# The entry point is Session; everything else is a collaborator it wires up.
module MermaidPreview
  # Everything raised on purpose. exe/mmd-preview turns these into a message and
  # a non-zero exit — anything else is a bug and keeps its backtrace.
  class Error < StandardError; end

  # Bad arguments. The message is meant to be printed as-is.
  class UsageError < Error; end

  # Something we shell out to isn't installed.
  class MissingDependencyError < Error; end

  # Not a failure: --help unwinding the parser so only the executable exits.
  class HelpRequested < Error; end
end

require_relative "mermaid_preview/browser"
require_relative "mermaid_preview/browsers"
require_relative "mermaid_preview/cli"
require_relative "mermaid_preview/doctor"
require_relative "mermaid_preview/executable"
require_relative "mermaid_preview/mmdc"
require_relative "mermaid_preview/options"
require_relative "mermaid_preview/paths"
require_relative "mermaid_preview/renderer"
require_relative "mermaid_preview/reporter"
require_relative "mermaid_preview/server"
require_relative "mermaid_preview/session"
require_relative "mermaid_preview/watcher"
require_relative "mermaid_preview/workspace"
