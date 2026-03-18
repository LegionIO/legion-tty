# frozen_string_literal: true

module Legion
  module TTY
    class ScreenManager
      attr_reader :overlay

      def initialize
        @stack = []
        @overlay = nil
        @render_queue = Queue.new
        @mutex = Mutex.new
      end

      def push(screen)
        @mutex.synchronize do
          @stack.last&.deactivate
          @stack.push(screen)
          screen.activate
        end
      end

      def pop
        @mutex.synchronize do
          return if @stack.size <= 1

          screen = @stack.pop
          screen.teardown
          @stack.last&.activate
        end
      end

      def active_screen
        @mutex.synchronize { @stack.last }
      end

      def show_overlay(overlay_obj)
        @mutex.synchronize { @overlay = overlay_obj }
      end

      def dismiss_overlay
        @mutex.synchronize { @overlay = nil }
      end

      def enqueue(update)
        @render_queue.push(update)
      end

      def drain_queue
        updates = []
        updates << @render_queue.pop until @render_queue.empty?
        updates
      end

      def teardown_all
        @mutex.synchronize do
          @stack.reverse_each(&:teardown)
          @stack.clear
        end
      end
    end
  end
end
