# Changelog

All notable changes to this project are documented here. This project adheres
to [Semantic Versioning](https://semver.org).

## [1.1.0] - 2026-07-05

- **Opt in with `tagged: true`.** Documents are tagged only when created with
  `Prawn::Document.new(tagged: true)`, matching the `tagged?` query and standard
  "tagged PDF" terminology. The `marked:` option is removed (no alias).
- Reduced the patching surface: **no `pdf-core` patches**. `MarkedContent` and
  `StructureTree` now live under `Prawn::Accessibility` and use only the public
  renderer API; the structure tree is owned by the document and finalized via
  the existing `before_render` hook. The high-level API is mixed into
  `Prawn::Document` with `include`.
- Untagged output is unchanged (byte-for-byte stock Prawn). Header cells are
  flagged at construction, so `Cell#header?` is consistent before and after draw.
- Removed the low-level `@api private` symbols `renderer.marked?`,
  `renderer.structure_tree`, `PDF::Core::MarkedContent`,
  `PDF::Core::StructureTree`, and `PDF::Core::ObjectStore#marked?`.

## [1.0.0] - 2026-07-05

Initial release.

- Tagged-PDF (Section 508 / WCAG) support layered onto published `prawn`
  (`~> 2.5`) and `pdf-core` (`~> 0.10`) via `prepend` and additive re-opens —
  no forking.
- High-level document API on `Prawn::Document`: `tagged?`, `structure`,
  `structure_container`, `artifact`, `heading`, `paragraph`, `figure`, plus the
  `marked:` and `language:` document options.
- Structure attributes: `:Alt`, `:ActualText`, `:Lang`, `:Scope`.
- Low-level `PDF::Core::MarkedContent` (BMC/BDC/EMC) and
  `PDF::Core::StructureTree` (StructTreeRoot, structure elements, ParentTree,
  MCID allocation).
- Optional `prawn-table` (`~> 0.2`) tagging: `<Table>`/`<TR>`/`<TH>`/`<TD>`
  with header detection and `/Scope`. Activated automatically when
  `prawn-table` is present; not a required dependency.

Repackaged from the stalled upstream PRs prawnpdf/pdf-core#67,
prawnpdf/prawn#1391, and prawnpdf/prawn-table#164.

[1.1.0]: https://github.com/mes-amis/prawn-accessibility/releases/tag/v1.1.0
[1.0.0]: https://github.com/mes-amis/prawn-accessibility/releases/tag/v1.0.0
