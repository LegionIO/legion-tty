# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'
require 'fileutils'
require 'legion/tty/screens/config'

RSpec.describe Legion::TTY::Screens::Config do
  let(:app) { double('app') }
  let(:tmpdir) { Dir.mktmpdir }
  let(:config_file) { File.join(tmpdir, 'test.json') }
  let(:output) { StringIO.new }

  before do
    File.write(config_file, JSON.generate({ 'key' => 'value', 'secret' => 'vault://path#key' }))
  end

  after { FileUtils.rm_rf(tmpdir) }

  subject(:screen) { described_class.new(app, output: output, config_dir: tmpdir) }

  describe '#initialize' do
    it 'stores the app reference' do
      expect(screen.app).to eq(app)
    end

    it 'inherits from Base' do
      expect(screen).to be_a(Legion::TTY::Screens::Base)
    end

    it 'starts in file list mode' do
      expect(screen.instance_variable_get(:@viewing_file)).to be(false)
    end

    it 'starts with selected_file at 0' do
      expect(screen.instance_variable_get(:@selected_file)).to eq(0)
    end

    it 'starts with selected_key at 0' do
      expect(screen.instance_variable_get(:@selected_key)).to eq(0)
    end
  end

  describe '#activate' do
    it 'populates @files from the config directory' do
      screen.activate
      expect(screen.instance_variable_get(:@files)).not_to be_empty
    end

    it 'returns file entries with :name and :path keys' do
      screen.activate
      files = screen.instance_variable_get(:@files)
      expect(files.first).to include(:name, :path)
    end
  end

  describe '#discover_config_files' do
    it 'returns json files from the config dir' do
      screen.activate
      files = screen.discover_config_files
      expect(files.size).to eq(1)
      expect(files.first[:name]).to eq('test.json')
    end

    it 'returns empty array when dir does not exist' do
      nonexistent = described_class.new(app, config_dir: '/nonexistent/path/xyz')
      expect(nonexistent.discover_config_files).to eq([])
    end

    it 'returns multiple files sorted by name' do
      File.write(File.join(tmpdir, 'aaa.json'), '{}')
      File.write(File.join(tmpdir, 'zzz.json'), '{}')
      files = screen.discover_config_files
      names = files.map { |f| f[:name] }
      expect(names).to eq(names.sort)
    end

    it 'ignores non-json files' do
      File.write(File.join(tmpdir, 'notes.txt'), 'ignore me')
      files = screen.discover_config_files
      expect(files.none? { |f| f[:name] == 'notes.txt' }).to be(true)
    end
  end

  describe '#render' do
    context 'with no files' do
      subject(:empty_screen) { described_class.new(app, config_dir: '/nonexistent/path/xyz') }

      before { empty_screen.activate }

      it 'returns an array of strings' do
        result = empty_screen.render(80, 24)
        expect(result).to be_an(Array)
        result.each { |line| expect(line).to be_a(String) }
      end

      it 'returns exactly height lines' do
        result = empty_screen.render(80, 24)
        expect(result.size).to eq(24)
      end

      it 'shows the Settings header' do
        result = empty_screen.render(80, 24)
        joined = result.join("\n")
        expect(joined).to include('Settings')
      end

      it 'shows an empty file list' do
        result = empty_screen.render(80, 24)
        file_lines = result.select { |l| l.include?('.json') }
        expect(file_lines).to be_empty
      end
    end

    context 'with files present' do
      before { screen.activate }

      it 'returns exactly height lines' do
        result = screen.render(80, 24)
        expect(result.size).to eq(24)
      end

      it 'shows the file name in the list' do
        result = screen.render(80, 24)
        joined = result.join("\n")
        expect(joined).to include('test.json')
      end

      it 'shows the Settings header' do
        result = screen.render(80, 24)
        joined = result.join("\n")
        expect(joined).to include('Settings')
      end

      it 'shows navigation hint' do
        result = screen.render(80, 24)
        joined = result.join("\n")
        expect(joined).to include('Enter=view')
      end
    end

    context 'in file view mode' do
      before do
        screen.activate
        screen.instance_variable_set(:@viewing_file, true)
        screen.instance_variable_set(:@file_data, { 'key' => 'value', 'secret' => 'vault://path#key' })
      end

      it 'shows the key names' do
        result = screen.render(80, 24)
        joined = result.join("\n")
        expect(joined).to include('key')
      end

      it 'masks vault:// values' do
        result = screen.render(80, 24)
        joined = result.join("\n")
        expect(joined).to include('********')
        expect(joined).not_to include('vault://path#key')
      end
    end
  end

  describe '#handle_input in file list mode' do
    before { screen.activate }

    it 'returns :handled for :up' do
      expect(screen.handle_input(:up)).to eq(:handled)
    end

    it 'returns :handled for :down' do
      expect(screen.handle_input(:down)).to eq(:handled)
    end

    it 'navigates down incrementing selected_file' do
      # Add a second file so we can navigate
      File.write(File.join(tmpdir, 'second.json'), '{}')
      screen.activate
      screen.handle_input(:down)
      expect(screen.instance_variable_get(:@selected_file)).to eq(1)
    end

    it 'does not go below 0 on :up when already at top' do
      screen.handle_input(:up)
      expect(screen.instance_variable_get(:@selected_file)).to eq(0)
    end

    it 'returns :handled for :enter' do
      expect(screen.handle_input(:enter)).to eq(:handled)
    end

    it 'returns :pop_screen for q' do
      expect(screen.handle_input('q')).to eq(:pop_screen)
    end

    it 'returns :pop_screen for :escape' do
      expect(screen.handle_input(:escape)).to eq(:pop_screen)
    end

    it 'returns :pass for unknown keys' do
      expect(screen.handle_input('x')).to eq(:pass)
    end
  end

  describe '#handle_input in file view mode' do
    before do
      screen.activate
      screen.handle_input(:enter)
      # Now in file view mode
    end

    it 'is in viewing_file mode after opening a file' do
      expect(screen.instance_variable_get(:@viewing_file)).to be(true)
    end

    it 'returns :handled for :up' do
      expect(screen.handle_input(:up)).to eq(:handled)
    end

    it 'returns :handled for :down' do
      expect(screen.handle_input(:down)).to eq(:handled)
    end

    it 'navigates down within keys' do
      screen.handle_input(:down)
      expect(screen.instance_variable_get(:@selected_key)).to eq(1)
    end

    it 'does not go below 0 on :up at top' do
      screen.handle_input(:up)
      expect(screen.instance_variable_get(:@selected_key)).to eq(0)
    end

    it 'returns :handled for q and goes back to file list' do
      result = screen.handle_input('q')
      expect(result).to eq(:handled)
      expect(screen.instance_variable_get(:@viewing_file)).to be(false)
    end

    it 'returns :handled for :escape and goes back to file list' do
      result = screen.handle_input(:escape)
      expect(result).to eq(:handled)
      expect(screen.instance_variable_get(:@viewing_file)).to be(false)
    end

    it 'resets selected_key to 0 when going back' do
      screen.handle_input(:down)
      screen.handle_input('q')
      expect(screen.instance_variable_get(:@selected_key)).to eq(0)
    end

    it 'returns :pass for unknown keys' do
      expect(screen.handle_input('x')).to eq(:pass)
    end
  end

  describe '#open_file' do
    before { screen.activate }

    it 'sets viewing_file to true' do
      screen.send(:open_file)
      expect(screen.instance_variable_get(:@viewing_file)).to be(true)
    end

    it 'populates file_data with parsed JSON' do
      screen.send(:open_file)
      data = screen.instance_variable_get(:@file_data)
      expect(data['key']).to eq('value')
    end

    it 'handles JSON parse errors gracefully' do
      File.write(config_file, 'not valid json{{{')
      screen.activate
      expect { screen.send(:open_file) }.not_to raise_error
      data = screen.instance_variable_get(:@file_data)
      expect(data['error']).to eq('Failed to parse file')
    end

    it 'handles missing files gracefully' do
      screen.instance_variable_set(:@files, [{ name: 'gone.json', path: '/nonexistent/gone.json' }])
      expect { screen.send(:open_file) }.not_to raise_error
      data = screen.instance_variable_get(:@file_data)
      expect(data['error']).to eq('Failed to parse file')
    end

    it 'resets selected_key to 0 when opening a file' do
      screen.instance_variable_set(:@selected_key, 5)
      screen.send(:open_file)
      expect(screen.instance_variable_get(:@selected_key)).to eq(0)
    end

    it 'does nothing when no file is selected' do
      screen.instance_variable_set(:@files, [])
      screen.send(:open_file)
      expect(screen.instance_variable_get(:@viewing_file)).to be(false)
    end
  end

  describe '#masked?' do
    it 'returns true for vault:// prefix' do
      expect(screen.send(:masked?, 'vault://secret/path#key')).to be(true)
    end

    it 'returns true for env:// prefix' do
      expect(screen.send(:masked?, 'env://MY_SECRET_VAR')).to be(true)
    end

    it 'returns false for plain strings' do
      expect(screen.send(:masked?, 'plaintext')).to be(false)
    end

    it 'returns false for empty string' do
      expect(screen.send(:masked?, '')).to be(false)
    end

    it 'returns false for http:// (not a masked prefix)' do
      expect(screen.send(:masked?, 'http://example.com')).to be(false)
    end
  end

  describe '#format_value' do
    it 'shows hash size for Hash values' do
      result = screen.send(:format_value, { 'a' => 1, 'b' => 2 })
      expect(result).to include('{2 keys}')
    end

    it 'shows array size for Array values' do
      result = screen.send(:format_value, [1, 2, 3])
      expect(result).to include('[3 items]')
    end

    it 'masks vault:// string values' do
      result = screen.send(:format_value, 'vault://secret/path#key')
      expect(result).to include('********')
      expect(result).not_to include('vault://')
    end

    it 'masks env:// string values' do
      result = screen.send(:format_value, 'env://MY_VAR')
      expect(result).to include('********')
    end

    it 'returns plain string values as-is' do
      result = screen.send(:format_value, 'hello')
      expect(result).to eq('hello')
    end

    it 'converts non-string scalars to strings' do
      result = screen.send(:format_value, 42)
      expect(result).to eq('42')
    end
  end

  describe '#save_current_file' do
    before do
      screen.activate
      screen.send(:open_file)
    end

    it 'writes file_data back to disk as pretty JSON' do
      screen.instance_variable_get(:@file_data)['key'] = 'updated'
      screen.send(:save_current_file)
      written = ::JSON.parse(File.read(config_file))
      expect(written['key']).to eq('updated')
    end

    it 'does nothing when no file is selected' do
      screen.instance_variable_set(:@files, [])
      expect { screen.send(:save_current_file) }.not_to raise_error
    end
  end

  describe '#render returns correct line count' do
    it 'always returns exactly height lines in list mode' do
      screen.activate
      [10, 24, 40].each do |h|
        result = screen.render(80, h)
        expect(result.size).to eq(h), "Expected #{h} lines, got #{result.size}"
      end
    end

    it 'always returns exactly height lines in file view mode' do
      screen.activate
      screen.send(:open_file)
      [10, 24, 40].each do |h|
        result = screen.render(80, h)
        expect(result.size).to eq(h), "Expected #{h} lines, got #{result.size}"
      end
    end
  end
end
