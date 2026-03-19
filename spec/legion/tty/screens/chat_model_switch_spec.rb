# frozen_string_literal: true

require 'spec_helper'
require 'legion/tty/screens/chat'

RSpec.describe Legion::TTY::Screens::Chat, 'model switching' do
  let(:output) { StringIO.new }
  let(:reader) { double('reader', read_line: nil) }
  let(:input_bar) { Legion::TTY::Components::InputBar.new(name: 'Test', reader: reader) }
  let(:app) do
    instance_double('Legion::TTY::App',
                    config: { provider: 'claude' },
                    llm_chat: nil,
                    screen_manager: double('sm', overlay: nil, push: nil, pop: nil, dismiss_overlay: nil,
                                                 show_overlay: nil),
                    hotkeys: double('hk', list: []),
                    respond_to?: true)
  end

  before do
    allow(app).to receive(:respond_to?).with(:config).and_return(true)
    allow(app).to receive(:respond_to?).with(:llm_chat).and_return(true)
    allow(app).to receive(:respond_to?).with(:screen_manager).and_return(true)
    allow(app).to receive(:respond_to?).with(:hotkeys).and_return(true)
    allow(app).to receive(:respond_to?).with(:toggle_dashboard).and_return(false)
  end

  describe '#handle_slash_command with /model' do
    it 'shows current model with no argument' do
      chat = described_class.new(app, output: output, input_bar: input_bar)
      result = chat.handle_slash_command('/model')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('Current model')
    end

    it 'attempts model switch with argument' do
      llm_chat = double('llm_chat', respond_to?: true, with_model: nil, model: 'test-model')
      allow(llm_chat).to receive(:respond_to?).with(:with_model).and_return(true)
      allow(llm_chat).to receive(:respond_to?).with(:model).and_return(true)
      allow(llm_chat).to receive(:respond_to?).with(:with_instructions).and_return(false)
      allow(app).to receive(:llm_chat).and_return(llm_chat)

      chat = described_class.new(app, output: output, input_bar: input_bar)
      result = chat.handle_slash_command('/model test-model')
      expect(result).to eq(:handled)
    end

    it 'handles switch failure gracefully' do
      llm_chat = double('llm_chat')
      allow(llm_chat).to receive(:respond_to?).and_return(true)
      allow(llm_chat).to receive(:with_model).and_raise(StandardError.new('bad model'))
      allow(llm_chat).to receive(:with_instructions)
      allow(app).to receive(:llm_chat).and_return(llm_chat)

      chat = described_class.new(app, output: output, input_bar: input_bar)
      result = chat.handle_slash_command('/model bad-model')
      expect(result).to eq(:handled)
      expect(chat.message_stream.messages.last[:content]).to include('Failed to switch model')
    end
  end
end
