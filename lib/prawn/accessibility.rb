# frozen_string_literal: true

require_relative 'accessibility/version'
require_relative 'accessibility/document'

# prawn-table support is optional. If the gem is installed, load it and apply
# the table tagging patches; otherwise carry on without table support.
begin
  require 'prawn/table'
rescue LoadError
  # prawn-table is not available; table tagging is disabled.
end

require_relative 'accessibility/table' if defined?(Prawn::Table)
