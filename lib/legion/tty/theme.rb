# frozen_string_literal: true

module Legion
  module TTY
    # rubocop:disable Metrics/ModuleLength
    module Theme
      # rubocop:disable Naming/VariableNumber
      THEMES = {
        purple: {
          palette: {
            shade_1: [30, 27, 46], shade_2: [41, 37, 63], shade_3: [52, 47, 80],
            shade_4: [63, 57, 97], shade_5: [74, 67, 114], shade_6: [85, 77, 131],
            shade_7: [96, 87, 148], shade_8: [107, 97, 165], shade_9: [118, 107, 182],
            shade_10: [129, 119, 199], shade_11: [140, 131, 210], shade_12: [157, 148, 221],
            shade_13: [174, 167, 230], shade_14: [191, 186, 239], shade_15: [208, 205, 245],
            shade_16: [225, 224, 250], shade_17: [242, 243, 255]
          },
          semantic: {
            primary: :shade_9, secondary: :shade_6, accent: :shade_12,
            success: [0, 200, 83], warning: [255, 191, 0], error: [255, 69, 58],
            info: :shade_7, surface: :shade_1, muted: :shade_4,
            rain: :shade_11, rain_fade: :shade_3
          }
        },
        green: {
          palette: {
            shade_1: [15, 30, 15], shade_2: [20, 45, 20], shade_3: [25, 60, 25],
            shade_4: [30, 75, 30], shade_5: [35, 90, 35], shade_6: [40, 110, 40],
            shade_7: [50, 130, 50], shade_8: [60, 150, 60], shade_9: [75, 170, 75],
            shade_10: [90, 190, 90], shade_11: [110, 210, 110], shade_12: [140, 225, 140],
            shade_13: [170, 235, 170], shade_14: [195, 242, 195], shade_15: [215, 248, 215],
            shade_16: [230, 252, 230], shade_17: [245, 255, 245]
          },
          semantic: {
            primary: :shade_9, secondary: :shade_6, accent: :shade_12,
            success: [0, 200, 83], warning: [255, 191, 0], error: [255, 69, 58],
            info: :shade_7, surface: :shade_1, muted: :shade_4,
            rain: :shade_11, rain_fade: :shade_3
          }
        },
        blue: {
          palette: {
            shade_1: [15, 20, 40], shade_2: [20, 30, 60], shade_3: [25, 40, 80],
            shade_4: [30, 50, 100], shade_5: [40, 65, 120], shade_6: [50, 80, 140],
            shade_7: [65, 100, 160], shade_8: [80, 120, 180], shade_9: [100, 140, 200],
            shade_10: [120, 160, 215], shade_11: [145, 185, 225], shade_12: [170, 205, 235],
            shade_13: [195, 220, 242], shade_14: [210, 230, 248], shade_15: [225, 240, 252],
            shade_16: [238, 248, 255], shade_17: [248, 252, 255]
          },
          semantic: {
            primary: :shade_9, secondary: :shade_6, accent: :shade_12,
            success: [0, 200, 83], warning: [255, 191, 0], error: [255, 69, 58],
            info: :shade_7, surface: :shade_1, muted: :shade_4,
            rain: :shade_11, rain_fade: :shade_3
          }
        },
        amber: {
          palette: {
            shade_1: [35, 25, 10], shade_2: [50, 35, 15], shade_3: [65, 45, 20],
            shade_4: [80, 55, 25], shade_5: [100, 70, 30], shade_6: [120, 85, 35],
            shade_7: [140, 100, 40], shade_8: [165, 120, 50], shade_9: [190, 140, 60],
            shade_10: [210, 160, 70], shade_11: [225, 180, 85], shade_12: [235, 200, 110],
            shade_13: [242, 215, 140], shade_14: [248, 230, 170], shade_15: [252, 240, 200],
            shade_16: [255, 248, 225], shade_17: [255, 252, 245]
          },
          semantic: {
            primary: :shade_9, secondary: :shade_6, accent: :shade_12,
            success: [0, 200, 83], warning: [255, 191, 0], error: [255, 69, 58],
            info: :shade_7, surface: :shade_1, muted: :shade_4,
            rain: :shade_11, rain_fade: :shade_3
          }
        }
      }.freeze

      # Legacy aliases for backward compatibility
      PALETTE = THEMES[:purple][:palette].transform_keys { |k| k.to_s.sub('shade_', 'purple_').to_sym }.freeze
      SEMANTIC = THEMES[:purple][:semantic].freeze
      # rubocop:enable Naming/VariableNumber

      class << self
        def current_theme
          @current_theme || :purple
        end

        # rubocop:disable Naming/PredicateMethod
        def switch(name)
          name = name.to_sym
          return false unless THEMES.key?(name)

          @current_theme = name
          true
        end
        # rubocop:enable Naming/PredicateMethod

        def available_themes
          THEMES.keys
        end

        def c(name, text)
          rgb = resolve_rgb(name)
          return text unless rgb

          "\e[38;2;#{rgb[0]};#{rgb[1]};#{rgb[2]}m#{text}\e[0m"
        end

        def reset_theme
          @current_theme = :purple
        end

        private

        def resolve_rgb(name)
          theme = THEMES[current_theme]
          palette = theme[:palette]
          semantic = theme[:semantic]

          if palette.key?(name)
            palette[name]
          elsif semantic.key?(name)
            ref = semantic[name]
            ref.is_a?(Symbol) ? palette[ref] : ref
          elsif PALETTE.key?(name)
            PALETTE[name]
          end
        end
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
