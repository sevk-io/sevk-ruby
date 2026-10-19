# frozen_string_literal: true

module Sevk
  module Markup
    module TagScanner
      TagPatterns = Struct.new(:open, :close, :nested, :close_length)

      def tag_patterns(tag_name)
        TagPatterns.new(/<#{tag_name}([^>]*)>/i, %r{</#{tag_name}>}i, /<#{tag_name}/i, tag_name.length + 3)
      end

      def replace_self_closing(source, tag, self_close_only: false)
        open_pattern = /<#{tag}/i
        name_length = tag.length + 1
        output = +''
        last_index = 0
        position = 0

        while (opening = source.index(open_pattern, position))
          closing_bracket = source.index('>', opening + name_length)
          break unless closing_bracket

          position = closing_bracket + 1
          next if self_close_only && source[closing_bracket - 1] != '/'

          attributes_end = self_close_only ? closing_bracket - 1 : closing_bracket
          output << source[last_index...opening] << yield(source[(opening + name_length)...attributes_end])
          last_index = closing_bracket + 1
        end

        output << source[last_index..]
      end

      def get_first_tag_content(source, tag)
        scanner = StringScanner.new(source)
        return nil unless scanner.skip_until(/<#{tag}/i) && scanner.skip_until(/>/)

        content_start = scanner.pos
        return nil unless scanner.skip_until(%r{</#{tag}>}i)

        source.byteslice(content_start, scanner.pos - (tag.length + 3) - content_start)
      end

      def get_all_tag_contents(source, tag)
        open_pattern = /<#{tag}/i
        close_pattern = %r{</#{tag}>}i
        scanner = StringScanner.new(source)
        contents = []

        while scanner.skip_until(open_pattern) && scanner.skip_until(/>/)
          content_start = scanner.pos
          break unless scanner.skip_until(close_pattern)

          contents << source.byteslice(content_start, scanner.pos - (tag.length + 3) - content_start)
        end

        contents
      end

      def strip_tag_pairs(source, tag)
        open_pattern = /<#{tag}/i
        close_pattern = %r{</#{tag}>}i
        scanner = StringScanner.new(source)
        output = +''
        last_index = 0

        while scanner.skip_until(open_pattern)
          opening = scanner.pos - scanner.matched_size
          break unless scanner.skip_until(/>/) && scanner.skip_until(close_pattern)

          output << source.byteslice(last_index, opening - last_index)
          last_index = scanner.pos
        end

        output << source.byteslice(last_index, source.bytesize - last_index)
      end

      def get_tag_attributes(source, tag)
        open_pattern = /<#{tag}/i
        scanner = StringScanner.new(source)
        attributes = []

        while scanner.skip_until(open_pattern)
          attributes_start = scanner.pos
          break unless scanner.skip_until(/>/)

          attributes << source.byteslice(attributes_start, scanner.pos - 1 - attributes_start)
        end

        attributes
      end

      def find_hidden_preview_div(html)
        position = 0

        while (opening = html.index(/<div/i, position))
          closing_bracket = html.index('>', opening + 4)
          return nil unless closing_bracket

          if html[opening..closing_bracket].match?(/style=["'][^"']*display:\s*none/i)
            closing = html.index(%r{</div>}i, closing_bracket + 1)
            return nil unless closing

            return [html[opening...(closing + 6)], html[(closing_bracket + 1)...closing]]
          end

          position = closing_bracket + 1
        end
      end
    end
  end
end
