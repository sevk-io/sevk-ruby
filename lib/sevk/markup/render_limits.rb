# frozen_string_literal: true

module Sevk
  module Markup
    module RenderLimits
      MAX_MARKUP_DEPTH = 64
      MAX_TAG_ITERATIONS = 200
      MAX_RENDER_OUTPUT = 5_000_000
      MAX_TAG_SCAN_WORK = 30_000_000
      TOO_COMPLEX = 'Email markup is too complex to render'

      DEPTH_TAGS = %w[
        block section column row container heading paragraph text button link sevk-link list li codeblock
      ].freeze

      private

      def charge_scan_work(work)
        @scan_work += work
        raise ArgumentError, TOO_COMPLEX if @scan_work > MAX_TAG_SCAN_WORK
      end

      def assert_markup_depth(content)
        depths = Hash.new(0)
        index = 0

        while (open = content.index('<', index))
          close = content.index('>', open + 1)
          break unless close

          index = close + 1
          position = open + 1
          closing = content[position] == '/'
          position += 1 if closing
          name_end = position
          name_end += 1 while name_end < close && content[name_end].match?(/[A-Za-z-]/)
          name = content[position...name_end].downcase
          next unless DEPTH_TAGS.include?(name)

          if closing
            depths[name] -= 1 if depths[name].positive?
          elsif content[close - 1] != '/'
            depths[name] += 1
            if depths[name] > MAX_MARKUP_DEPTH
              raise ArgumentError, "Email markup nesting exceeds the maximum depth of #{MAX_MARKUP_DEPTH}"
            end
          end
        end
      end
    end
  end
end
