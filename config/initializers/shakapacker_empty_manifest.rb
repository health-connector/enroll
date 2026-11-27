# frozen_string_literal: true

# Shakapacker 10's npm package writes a placeholder "{}" manifest.json before webpack compiles.
# If that compile dies (killed, out of memory, webpack error), the placeholder looks like a
# finished build: on-demand compiles stop retrying and every page raises
# Shakapacker::Manifest::MissingEntryError until a watched file changes. Treat a manifest with no
# entries as stale, so the next request compiles again (or waits for a compile already running),
# as Shakapacker 9 did when no manifest existed yet.
module ShakapackerEmptyManifestIsStale
  def stale?
    empty_manifest? || super
  end

  def fresh?
    !stale?
  end

  private

  def empty_manifest?
    manifest_path = config.manifest_path
    manifest_path.exist? && JSON.parse(manifest_path.read).empty?
  rescue JSON::ParserError
    true
  end
end

Shakapacker::Compiler.prepend(ShakapackerEmptyManifestIsStale)
