# Changelog

All notable changes to this project are documented here. This project adheres
to [Semantic Versioning](https://semver.org).

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

[1.0.0]: https://github.com/mes-amis/prawn-accessibility/releases/tag/v1.0.0
