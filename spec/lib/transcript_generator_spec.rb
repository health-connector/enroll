# frozen_string_literal: true

require 'rails_helper'
require 'transcript_generator'

RSpec.describe TranscriptGenerator do
  let(:tmp_path) { Dir.mktmpdir('transcript_generator_spec') }

  # Redirect TRANSCRIPT_PATH to a temp dir for all tests
  before do
    stub_const('TranscriptGenerator::TRANSCRIPT_PATH', tmp_path)
  end

  after do
    FileUtils.rm_rf(tmp_path)
  end

  describe '#initialize' do
    it 'defaults market to individual' do
      tg = described_class.new
      expect(tg.instance_variable_get(:@market)).to eq('individual')
    end

    it 'accepts a market argument' do
      tg = described_class.new('shop')
      expect(tg.instance_variable_get(:@market)).to eq('shop')
    end
  end

  describe '#build_transcript — JSON serialisation' do
    let(:transcript_data) do
      {
        identifier: 'abc123',
        name: 'Jane Doe',
        changes: [{ field: 'email', from: 'a@b.com', to: 'c@d.com' }]
      }
    end

    let(:mock_transcript) do
      instance_double(
        Transcripts::PersonTranscript,
        transcript: transcript_data,
        find_or_build: nil
      )
    end

    let(:mock_external_obj) { double('external_obj') }

    before do
      allow(Transcripts::PersonTranscript).to receive(:new).and_return(mock_transcript)
      generator = described_class.new
      generator.instance_variable_set(:@count, 1)
      generator.build_transcript(mock_external_obj)
    end

    it 'writes exactly one .bin file to TRANSCRIPT_PATH' do
      files = Dir.glob("#{tmp_path}/*.bin")
      expect(files.size).to eq(1)
    end

    it 'writes valid JSON (not Marshal binary)' do
      file_path = Dir.glob("#{tmp_path}/*.bin").first
      content = File.read(file_path)
      expect { JSON.parse(content) }.not_to raise_error
    end

    it 'persists all transcript keys and values' do
      file_path = Dir.glob("#{tmp_path}/*.bin").first
      loaded = JSON.parse(File.read(file_path))
      expect(loaded['identifier']).to eq('abc123')
      expect(loaded['name']).to eq('Jane Doe')
      expect(loaded['changes'].first['field']).to eq('email')
    end

    it 'does not write Marshal binary format' do
      file_path = Dir.glob("#{tmp_path}/*.bin").first
      # Marshal binary files start with \x04\x08
      raw = File.binread(file_path)
      expect(raw).not_to start_with("\x04\x08")
    end
  end

  describe '#display_transcripts — JSON deserialisation round-trip' do
    let(:transcript_data) do
      {
        'hbx_id' => 'xyz789',
        'last_name' => 'Smith',
        'first_name' => 'Bob',
        'ssn' => '123456789'
      }
    end

    let(:bin_file) { File.join(tmp_path, '1_xyz789_123456789.bin') }

    let(:mock_importer) do
      instance_double(
        Importers::Transcripts::PersonTranscript,
        transcript: nil,
        market: nil,
        process: nil,
        csv_row: [[
          'xyz789', '123456789', 'Smith', 'Bob',
          'match', 'match:ssn', '', 'Matched'
        ]]
      )
    end

    before do
      # Write a JSON .bin file as build_transcript now produces
      File.write(bin_file, JSON.dump(transcript_data))

      allow(Importers::Transcripts::PersonTranscript).to receive(:new).and_return(mock_importer)
      allow(mock_importer).to receive(:transcript=) do |val|
        # Verify that what was loaded is a Hash with string keys (JSON round-trip)
        expect(val).to be_a(Hash)
        expect(val['hbx_id']).to eq('xyz789')
      end
      allow(mock_importer).to receive(:market=)
    end

    it 'reads the JSON file without raising' do
      generator = described_class.new
      expect { generator.display_transcripts }.not_to raise_error
    end

    it 'loads the transcript as a Hash with the correct keys' do
      generator = described_class.new
      generator.display_transcripts
      expect(mock_importer).to have_received(:transcript=).once
    end

    it 'produces a CSV output file' do
      generator = described_class.new
      generator.display_transcripts
      expect(File.exist?('person_change_sets.csv')).to be true
    end

    after do
      FileUtils.rm_f('person_change_sets.csv')
    end
  end

  describe 'security — no Marshal usage' do
    it 'does not call Marshal.load anywhere in build_transcript' do
      expect(Marshal).not_to receive(:load)
      generator = described_class.new
      mock_transcript = instance_double(
        Transcripts::PersonTranscript,
        transcript: { identifier: 'test' },
        find_or_build: nil
      )
      allow(Transcripts::PersonTranscript).to receive(:new).and_return(mock_transcript)
      generator.instance_variable_set(:@count, 1)
      generator.build_transcript(double('obj'))
    end

    it 'does not call Marshal.dump anywhere in build_transcript' do
      expect(Marshal).not_to receive(:dump)
      generator = described_class.new
      mock_transcript = instance_double(
        Transcripts::PersonTranscript,
        transcript: { identifier: 'test' },
        find_or_build: nil
      )
      allow(Transcripts::PersonTranscript).to receive(:new).and_return(mock_transcript)
      generator.instance_variable_set(:@count, 1)
      generator.build_transcript(double('obj'))
    end
  end
end
