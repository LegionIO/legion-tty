# frozen_string_literal: true

require 'legion/json'
require 'fileutils'

module Legion
  module TTY
    # KeybindingManager — context-aware keybinding system with chord support and user customization.
    #
    # Named contexts:
    #   :global, :chat, :dashboard, :extensions, :config, :command_palette, :session_picker, :history
    #
    # Chord sequences: two-key combos stored as "key1+key2" strings. Set @pending_chord between
    # key presses; the second key resolves the chord action.
    #
    # User overrides loaded from ~/.legionio/keybindings.json at boot.
    class KeybindingManager
      CONTEXTS = %i[global chat dashboard extensions config command_palette session_picker history].freeze

      OVERRIDES_PATH = File.expand_path('~/.legionio/keybindings.json')

      DEFAULT_BINDINGS = {
        ctrl_d: { contexts: %i[global chat], action: :toggle_dashboard, description: 'Toggle dashboard (Ctrl+D)' },
        ctrl_k: { contexts: %i[global chat], action: :command_palette, description: 'Open command palette (Ctrl+K)' },
        ctrl_s: { contexts: %i[global chat], action: :session_picker, description: 'Open session picker (Ctrl+S)' },
        ctrl_l: { contexts: %i[global chat dashboard], action: :refresh, description: 'Refresh screen (Ctrl+L)' },
        escape: { contexts: CONTEXTS, action: :back, description: 'Go back / dismiss overlay (Escape)' },
        tab: { contexts: %i[chat], action: :autocomplete, description: 'Auto-complete (Tab)' },
        ctrl_c: { contexts: CONTEXTS, action: :interrupt, description: 'Interrupt / quit (Ctrl+C)' }
      }.freeze

      def initialize(overrides_path: OVERRIDES_PATH)
        @overrides_path = overrides_path
        @bindings = {}
        @pending_chord = nil
        load_defaults
        load_user_overrides
      end

      # Resolve a key press given the currently active contexts.
      #
      # @param key [Symbol, String] normalized key (e.g. :ctrl_d, :escape)
      # @param active_contexts [Array<Symbol>] contexts currently in scope (most specific last)
      # @return [Symbol, nil] action name, or nil if no binding matches
      def resolve(key, active_contexts: [:global])
        key_sym = key.to_s.to_sym

        # Chord resolution: if a chord is pending, try to complete it
        if @pending_chord
          chord = :"#{@pending_chord}+#{key_sym}"
          @pending_chord = nil
          return action_for(chord, active_contexts)
        end

        # Check if this key starts a chord
        if chord_starter?(key_sym)
          @pending_chord = key_sym
          return :chord_pending
        end

        action_for(key_sym, active_contexts)
      end

      # Cancel any in-progress chord sequence.
      def cancel_chord
        @pending_chord = nil
      end

      # Whether a chord is currently waiting for its second key.
      def chord_pending?
        !@pending_chord.nil?
      end

      # Register or override a single binding.
      # @param key [Symbol, String] normalized key
      # @param action [Symbol] action name
      # @param contexts [Array<Symbol>] applicable contexts (:global means all)
      # @param description [String]
      def bind(key, action:, contexts: [:global], description: '')
        @bindings[key.to_s.to_sym] = { contexts: contexts, action: action, description: description }
      end

      # Remove a binding.
      def unbind(key)
        @bindings.delete(key.to_s.to_sym)
      end

      # All registered bindings as an array of hashes.
      def list
        @bindings.map do |key, b|
          { key: key, action: b[:action], contexts: b[:contexts], description: b[:description] }
        end
      end

      # Reload default bindings (resets user overrides).
      def load_defaults
        @bindings = {}
        DEFAULT_BINDINGS.each do |key, binding|
          @bindings[key] = binding.dup
        end
      end

      # Load user overrides from ~/.legionio/keybindings.json.
      # File format: { "ctrl_d": { "action": "toggle_dashboard", "contexts": ["global"], "description": "..." } }
      def load_user_overrides
        return unless File.exist?(@overrides_path)

        raw = Legion::JSON.parse(File.read(@overrides_path), symbolize_names: true)
        raw.each { |key, cfg| apply_override(key, cfg) }
      rescue Legion::JSON::ParseError => e
        Legion::Logging.warn("keybindings load failed: #{e.message}") if defined?(Legion::Logging)
      end

      private

      def action_for(key_sym, active_contexts)
        binding_entry = @bindings[key_sym]
        return nil unless binding_entry

        binding_contexts = binding_entry[:contexts]
        return binding_entry[:action] if binding_contexts.include?(:global)
        return binding_entry[:action] if binding_contexts.intersect?(active_contexts)

        nil
      end

      def apply_override(key, cfg)
        return unless cfg.is_a?(Hash) && cfg[:action]

        contexts = Array(cfg[:contexts] || [:global]).map(&:to_sym)
        @bindings[key.to_s.to_sym] = {
          contexts: contexts,
          action: cfg[:action].to_sym,
          description: cfg[:description].to_s
        }
      end

      def chord_starter?(key_sym)
        @bindings.keys.any? { |k| k.to_s.start_with?("#{key_sym}+") }
      end
    end
  end
end
