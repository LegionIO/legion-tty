# frozen_string_literal: true

module Legion
  module TTY
    module Theme
      # rubocop:disable Naming/VariableNumber
      PALETTE = {
        purple_1: [30, 27, 46],
        purple_2: [41, 37, 63],
        purple_3: [52, 47, 80],
        purple_4: [63, 57, 97],
        purple_5: [74, 67, 114],
        purple_6: [85, 77, 131],
        purple_7: [96, 87, 148],
        purple_8: [107, 97, 165],
        purple_9: [118, 107, 182],
        purple_10: [129, 119, 199],
        purple_11: [140, 131, 210],
        purple_12: [157, 148, 221],
        purple_13: [174, 167, 230],
        purple_14: [191, 186, 239],
        purple_15: [208, 205, 245],
        purple_16: [225, 224, 250],
        purple_17: [242, 243, 255]
      }.freeze

      SEMANTIC = {
        primary: :purple_9,
        secondary: :purple_6,
        accent: :purple_12,
        success: [0, 200, 83],
        warning: [255, 191, 0],
        error: [255, 69, 58],
        info: :purple_7,
        surface: :purple_1,
        muted: :purple_4,
        rain: :purple_11,
        rain_fade: :purple_3
      }.freeze
      # rubocop:enable Naming/VariableNumber

      class << self
        def c(name, text)
          rgb = resolve_rgb(name)
          return text unless rgb

          "\e[38;2;#{rgb[0]};#{rgb[1]};#{rgb[2]}m#{text}\e[0m"
        end

        private

        def resolve_rgb(name)
          if PALETTE.key?(name)
            PALETTE[name]
          elsif SEMANTIC.key?(name)
            ref = SEMANTIC[name]
            ref.is_a?(Symbol) ? PALETTE[ref] : ref
          end
        end
      end
    end
  end
end
