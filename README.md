# prawn-accessibility

[![CI](https://github.com/mes-amis/prawn-accessibility/actions/workflows/ci.yml/badge.svg)](https://github.com/mes-amis/prawn-accessibility/actions/workflows/ci.yml)

Tagged-PDF (GSA **Section 508** / **WCAG**) accessibility for [Prawn](https://github.com/prawnpdf/prawn).

`prawn-accessibility` adds a high-level API for marking document structure —
headings, paragraphs, figures, tables, and decorative artifacts — so Prawn can
produce accessible, tagged PDFs that screen readers can navigate.

It layers on top of the **published** `prawn`, `pdf-core`, and (optionally)
`prawn-table` gems — it does **not** fork them. The document API is mixed into
`Prawn::Document`; only a couple of small method wrappers remain (and none in
`pdf-core`).

Tagging is opt-in: create a document with `tagged: true`. Without it, output is
byte-for-byte identical to stock Prawn.

## Installation

```ruby
# Gemfile
gem 'prawn-accessibility'
```

`prawn` and `pdf-core` are pulled in automatically. Table tagging activates
automatically **if `prawn-table` is also in your bundle** — it is not a required
dependency:

```ruby
gem 'prawn-table' # optional; enables <Table>/<TR>/<TH>/<TD> tagging
```

## Usage

```ruby
require 'prawn-accessibility'

# Opt in with tagged: true; set language: for the document's /Lang.
pdf = Prawn::Document.new(tagged: true, language: 'en-US')

pdf.heading(1, 'Annual Report')                                   # <H1>
pdf.paragraph('Body text that a screen reader will read aloud.')  # <P>

pdf.structure(:Span, ActualText: 'required') { pdf.text('*') }    # replacement text
pdf.figure(alt_text: 'Company logo') { pdf.image('logo.png') }    # <Figure> with /Alt

pdf.artifact(type: :Pagination) { pdf.text('Page 1') }            # decorative, not read

# Tables auto-tag while the document is tagged:
pdf.table([['Name', 'Age'], ['Alice', '30']], header: true)       # <Table>/<TR>/<TH>/<TD>

pdf.render_file('report.pdf')
```

A document created without `tagged: true` renders a plain, untagged PDF.

### API

| Method | Emits |
|---|---|
| `pdf.tagged?` | whether the document is in tagged mode |
| `pdf.structure(tag, attrs) { … }` | a structure element wrapping marked content |
| `pdf.structure_container(tag, attrs) { … }` | a container whose children mark themselves |
| `pdf.artifact(type:) { … }` | decorative content (ignored by screen readers) |
| `pdf.heading(level, text, opts)` | `<H1>`–`<H6>` |
| `pdf.paragraph(text, opts)` / `{ … }` | `<P>` |
| `pdf.figure(alt_text:) { … }` | `<Figure>` with `/Alt` |

Supported structure attributes: `:Alt`, `:ActualText`, `:Lang`, `:Scope`.

## Compatibility

Semantic-versioned. The `~>` dependency bounds are the compatibility contract:

| prawn-accessibility | prawn | pdf-core | prawn-table (optional) |
|---|---|---|---|
| 1.x | `~> 2.5` | `~> 0.10` | `~> 0.2` |

Tested on Ruby 3.1–3.4.

## Development

```bash
bundle install
bundle exec rspec      # specs, including a regression suite proving untagged
                       # output is unaffected
bundle exec rubocop
```

## License

Tri-licensed under the same terms as Prawn: Matz's Ruby license (see
[LICENSE](LICENSE)) or [GPLv2](GPLv2) or [GPLv3](GPLv3). See [COPYING](COPYING)
for a summary.
