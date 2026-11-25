# frozen_string_literal: true

require "rails_helper"

RSpec.describe ShakapackerEmptyManifestIsStale do
  let(:manifest_dir) { Pathname.new(Dir.mktmpdir) }
  let(:manifest_path) { manifest_dir.join("manifest.json") }
  let(:config) { instance_double(Shakapacker::Configuration, manifest_path: manifest_path) }
  let(:strategy) { instance_double(Shakapacker::DigestStrategy, stale?: false, fresh?: true) }
  let(:compiler) { Shakapacker::Compiler.new(Shakapacker.instance) }

  before do
    allow(compiler).to receive(:config).and_return(config)
    allow(compiler).to receive(:strategy).and_return(strategy)
  end

  after { FileUtils.rm_rf(manifest_dir) }

  context "when the manifest is the empty placeholder from an unfinished compile" do
    before { manifest_path.write("{}") }

    it "treats the packs as stale even though the strategy says fresh" do
      expect(compiler.stale?).to be(true)
      expect(compiler.fresh?).to be(false)
    end
  end

  context "when the manifest is half written" do
    before { manifest_path.write('{"legacy.js": "/pa') }

    it "treats the packs as stale" do
      expect(compiler.stale?).to be(true)
    end
  end

  context "when the manifest has entries" do
    before { manifest_path.write({ "legacy.js" => "/packs/js/legacy.js" }.to_json) }

    it "uses the compiler strategy" do
      expect(compiler.stale?).to be(false)
      expect(compiler.fresh?).to be(true)
    end
  end

  context "when there is no manifest yet" do
    let(:strategy) { instance_double(Shakapacker::DigestStrategy, stale?: true, fresh?: false) }

    it "uses the compiler strategy" do
      expect(compiler.stale?).to be(true)
    end
  end
end
