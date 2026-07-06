# frozen_string_literal: true

require_relative 'lib/prawn/accessibility/version'

Gem::Specification.new do |spec|
  spec.name        = 'prawn-accessibility'
  spec.version     = Prawn::Accessibility::VERSION
  spec.authors     = ['Mes Amis']
  spec.email       = ['craig@monami.io']

  spec.summary     = 'Tagged PDF (Section 508 / WCAG) accessibility for Prawn.'
  spec.description = <<~DESC
    prawn-accessibility layers tagged-PDF support onto the published prawn,
    pdf-core, and (optionally) prawn-table gems. It adds a high-level API for
    marking document structure — headings, paragraphs, figures, tables, and
    artifacts — so Prawn can produce Section 508 / WCAG accessible PDFs.
  DESC

  spec.homepage    = 'https://github.com/mes-amis/prawn-accessibility'

  # Tri-licensed under the same terms as Prawn: Matz's Ruby license
  # ("Nonstandard", see LICENSE) or GPLv2 or GPLv3.
  spec.licenses    = %w[Nonstandard GPL-2.0-only GPL-3.0-only]

  spec.required_ruby_version = '>= 3.0'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri']   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb'] + %w[README.md CHANGELOG.md COPYING LICENSE GPLv2 GPLv3]
  spec.require_paths = ['lib']

  # Runtime dependencies. The pessimistic constraints are the compatibility
  # contract: the patched methods are pinned to the 2.5.x / 0.10.x shapes.
  spec.add_dependency 'pdf-core', '~> 0.10'
  spec.add_dependency 'prawn', '~> 2.5'
  # NOTE: prawn-table is intentionally NOT a runtime dependency. Table tagging
  # is applied automatically when prawn-table is present in the host bundle.
end
