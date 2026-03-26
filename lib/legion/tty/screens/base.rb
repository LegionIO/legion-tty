# frozen_string_literal: true

module Legion
  module TTY
    module Screens
      class Base
        attr_reader :app

        def initialize(app)
          @app = app
        end

        def activate; end
        def deactivate; end

        def render(_width, _height)
          raise NotImplementedError, "#{self.class}#render must be implemented"
        end

        def handle_input(_key)
          :pass
        end

        def needs_input_bar?
          false
        end

        def teardown; end
      end
    end
  end
end
