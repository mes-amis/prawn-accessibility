# frozen_string_literal: true

# Table accessibility patches. This file is only loaded when Prawn::Table is
# already defined (see prawn/accessibility.rb), so requiring prawn-accessibility
# without prawn-table installed is safe.
#
# prawn-table hard-instantiates Prawn::Table and offers no hook around cell
# drawing, so these three `prepend`s are the irreducible patching until upstream
# grows render hooks:
#
#   1. Prawn::Table#initialize      — flag header cells (at construction)
#   2. Prawn::Table#draw            — wrap the whole table in <Table>
#   3. Prawn::Table::Cell.draw_cells — wrap each row/cell in <TR>/<TH>/<TD>
#
# #draw and .draw_cells delegate to `super` in the untagged path, so untagged
# tables are unchanged. Everything else here is additive (new methods only).

unless defined?(Prawn::Table)
  raise 'prawn/accessibility/table requires prawn-table to be loaded first'
end

module Prawn
  module Accessibility
    # Patches applied to the published +prawn-table+ gem so that tables emit
    # +<Table>+/+<TR>+/+<TH>+/+<TD>+ structure elements when the owning document
    # is tagged.
    #
    # @api private
    module TablePatch
      # Prepended onto {Prawn::Table}. Flags header cells at construction (so
      # +Cell#header?+ is consistent whether or not the table has been drawn),
      # and wraps drawing in a +<Table>+ structure element when the document is
      # tagged.
      #
      # @api private
      module TableInstancePatch
        def initialize(*args, &block)
          super
          mark_header_cells
        end

        def draw
          if @pdf.respond_to?(:tagged?) && @pdf.tagged?
            @pdf.structure_container(:Table) { super() }
          else
            super
          end
        end

        # Marks cells in header rows as header cells for accessibility.
        #
        # @return [void]
        def mark_header_cells
          n = number_of_header_rows
          return if n.zero?

          @cells.each do |cell|
            cell.is_header_cell = true if cell.row < n
          end
        end
      end

      # Prepended onto the {Prawn::Table::Cell} singleton so
      # <tt>Cell.draw_cells</tt> emits row/cell structure tags in tagged mode.
      #
      # @api private
      module CellClassPatch
        def draw_cells(cells)
          return super if cells.empty?

          first_entry = cells.first
          first_cell = first_entry.is_a?(Array) ? first_entry[0] : first_entry
          pdf = first_cell.instance_variable_get(:@pdf)
          tagged = pdf.respond_to?(:tagged?) && pdf.tagged?

          return super unless tagged

          # Phase 1: backgrounds (decorative — artifact in tagged mode)
          pdf.artifact(type: :Layout) do
            cells.each do |cell, pt|
              cell.set_width_constraints
              cell.draw_background(pt)
            end
          end

          # Phase 2: borders and content, wrapped in TR/TH/TD structure
          draw_cells_tagged(cells, pdf)
        end

        # Draw cells with accessibility structure tags (TR, TH, TD).
        #
        # @api private
        def draw_cells_tagged(cells, pdf)
          # Group cells by row for TR wrapping
          rows = cells.group_by { |cell, _pt| cell.row }

          rows.sort_by { |row_num, _| row_num }.each do |_row_num, row_cells|
            pdf.structure_container(:TR) do
              row_cells.each do |cell, pt|
                # Skip span dummy cells — the master cell handles drawing
                next if cell.is_a?(Prawn::Table::Cell::SpanDummy)

                # Borders are decorative
                pdf.artifact(type: :Layout) { cell.draw_borders(pt) }

                # Content gets TH or TD tag
                tag = cell.header? ? :TH : :TD
                attrs = {}
                attrs[:Scope] = :Column if tag == :TH

                pdf.structure(tag, attrs) do
                  cell.draw_content_only(pt)
                end
              end
            end
          end
        end
      end
    end
  end
end

# --- Additive re-open of Prawn::Table::Cell ---------------------------------

module Prawn
  class Table
    class Cell
      # Whether this cell is a header cell (TH) for accessibility. Set
      # automatically for cells in header rows when the table has
      # <tt>header: true</tt>.
      attr_accessor :is_header_cell

      # Whether this cell is a header cell.
      #
      # @return [Boolean]
      def header?
        !!@is_header_cell
      end

      # Draws only the cell content (no borders or background). Used by the
      # tagged PDF rendering path where borders are drawn separately as
      # artifacts.
      #
      # @api private
      def draw_content_only(pt)
        draw_bounded_content(pt)
      end
    end
  end
end

Prawn::Table.prepend(Prawn::Accessibility::TablePatch::TableInstancePatch)
Prawn::Table::Cell.singleton_class.prepend(
  Prawn::Accessibility::TablePatch::CellClassPatch,
)
