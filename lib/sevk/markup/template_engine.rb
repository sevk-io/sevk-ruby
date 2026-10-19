# frozen_string_literal: true

module Sevk
  module Markup
    module TemplateEngine
      MAX_IF_PASSES = 2000
      MAX_EACH_ITEMS = 1000
      MAX_EACH_OUTPUT = 2_000_000
      MAX_TEMPLATE_WORK = 20_000_000
      OUTPUT_EXCEEDED = 'Email block exceeds the maximum template output size'

      private

      def truthy?(val)
        return false if val.nil?
        return false if val == false
        return false if val.is_a?(Numeric) && val.zero?
        return false if val.is_a?(String) && val.empty?
        return false if val.is_a?(Array) && val.empty?

        true
      end

      def evaluate_condition(expr, config)
        trimmed = expr.strip

        return trimmed.split('||').any? { |part| evaluate_condition(part, config) } if trimmed.include?('||')

        return trimmed.split('&&').all? { |part| evaluate_condition(part, config) } if trimmed.include?('&&')

        if (eq_match = trimmed.match(/^(\w+)\s*==\s*"([^"]*)"$/))
          return template_text(config[eq_match[1]]) == eq_match[2]
        end

        if (neq_match = trimmed.match(/^(\w+)\s*!=\s*"([^"]*)"$/))
          return template_text(config[neq_match[1]]) != neq_match[2]
        end

        truthy?(config[trimmed])
      end

      def render_template(template, config)
        @template_rendered = 0
        result = render_conditionals(template, config)
        result = render_loops(result, config)

        result = result.gsub(/\{%(\w+)\s*\?\?([^%]+)%\}/) do
          value = config[Regexp.last_match(1)]
          charge_template_output(value.nil? || value == '' ? Regexp.last_match(2).strip : template_text(value))
        end

        result.gsub(/\{%(\w+)%\}/) { charge_template_output(template_text(config[Regexp.last_match(1)])) }
      end

      def charge_template_output(value)
        raise ArgumentError, OUTPUT_EXCEEDED if @template_rendered + value.length > MAX_EACH_OUTPUT

        @template_rendered += value.length
        value
      end

      def render_conditionals(template, config)
        result = template
        pattern = %r{\{%#if\s+([^%]+)%\}((?:(?!\{%#if\s)[\s\S])*?)\{%/if%\}}
        work = 0

        MAX_IF_PASSES.times do
          work += result.length
          raise ArgumentError, RenderLimits::TOO_COMPLEX if work > MAX_TEMPLATE_WORK

          replaced = result.sub(pattern) do
            condition = Regexp.last_match(1)
            body = Regexp.last_match(2)
            else_index = body.index('{%else%}')
            if else_index.nil?
              evaluate_condition(condition, config) ? body : ''
            else
              evaluate_condition(condition, config) ? body[0...else_index] : body[(else_index + 8)..]
            end
          end
          break if replaced == result

          result = replaced
        end

        result
      end

      def render_loops(template, config)
        return template unless template.include?('{%/each%}')

        output = +''
        from = 0
        work = 0

        while from <= template.length
          open = template.match(/\{%#each\s+(\w+)(?:\s+as\s+(\w+))?%\}/, from)
          if open.nil?
            output << template[from..]
            break
          end

          body_start = open.end(0)
          close_index = template.index('{%/each%}', body_start)
          if close_index.nil?
            output << template[from..]
            break
          end

          output << template[from...open.begin(0)]
          items = config[open[1]]

          if items.is_a?(Array) && !items.empty?
            if items.length > MAX_EACH_ITEMS
              raise ArgumentError, "Email block exceeds the maximum of #{MAX_EACH_ITEMS} loop items"
            end

            alias_name = open[2] || 'this'
            body = template[body_start...close_index]
            property_pattern = /\{%#{Regexp.escape(alias_name)}\.(\w+)%\}/

            items.each do |item|
              work += body.length + 16
              raise ArgumentError, RenderLimits::TOO_COMPLEX if work > MAX_TEMPLATE_WORK

              output << render_loop_item(body, item, config, property_pattern)
            end
          end

          from = close_index + 9
        end

        output
      end

      def item_property(item, name)
        return item[name] if item.is_a?(Hash)
        return nil unless name == 'length'

        case item
        when String then item.encode('UTF-16LE').bytesize / 2
        when Array then item.length
        end
      end

      def render_loop_item(body, item, config, property_pattern)
        item_out = 0
        charge = lambda do |value|
          raise ArgumentError, OUTPUT_EXCEEDED if @template_rendered + item_out + value.length > MAX_EACH_OUTPUT

          item_out += value.length
          value
        end

        rendered = body.gsub(property_pattern) { charge.call(template_text(item_property(item, Regexp.last_match(1)))) }
        rendered = rendered.gsub(/\{%(\w+)%\}/) { charge.call(template_text(config[Regexp.last_match(1)])) }
        @template_rendered += rendered.length
        raise ArgumentError, OUTPUT_EXCEEDED if @template_rendered > MAX_EACH_OUTPUT

        rendered
      end

      def template_text(value)
        case value
        when nil then ''
        when true then 'true'
        when false then 'false'
        when Integer, Float then js_number(value.to_f)
        when Hash then '[object Object]'
        when Array then value.map { |item| item.is_a?(Hash) ? '[object Object]' : template_text(item) }.join(',')
        else value.to_s
        end
      end

      def process_block_tag(attrs, inner = '')
        template = inner.strip.empty? ? (attrs['template'] || '') : inner.strip
        return '' if template.empty?

        config_str = (attrs['config'] || '{}').gsub(/&(?:amp|quot|apos|lt|gt|#39|#x27|#34|#x22);/i) do |entity|
          {
            '&amp;' => '&', '&quot;' => '"', '&#34;' => '"', '&#x22;' => '"',
            '&apos;' => "'", '&#39;' => "'", '&#x27;' => "'", '&lt;' => '<', '&gt;' => '>'
          }.fetch(entity.downcase)
        end
        config = begin
          JSON.parse(config_str)
        rescue JSON::ParserError
          begin
            JSON.parse(config_str.gsub("'", '"'))
          rescue JSON::ParserError
            {}
          end
        end
        render_template(template, config.is_a?(Hash) ? config : {})
      end

      def parse_padding(style)
        pt = pr = pb = pl = 0
        if style['padding']
          parts = style['padding'].split
          case parts.length
          when 1
            val = parse_px(parts[0])
            pt = pr = pb = pl = val
          when 2
            vertical = parse_px(parts[0])
            horizontal = parse_px(parts[1])
            pt = vertical
            pr = horizontal
            pb = vertical
            pl = horizontal
          when 3
            pt = parse_px(parts[0])
            pr = parse_px(parts[1])
            pb = parse_px(parts[2])
            pl = parse_px(parts[1])
          when 4
            pt = parse_px(parts[0])
            pr = parse_px(parts[1])
            pb = parse_px(parts[2])
            pl = parse_px(parts[3])
          end
        end
        pt = parse_px(style['padding-top']) if style['padding-top']
        pr = parse_px(style['padding-right']) if style['padding-right']
        pb = parse_px(style['padding-bottom']) if style['padding-bottom']
        pl = parse_px(style['padding-left']) if style['padding-left']
        [pt, pr, pb, pl]
      end

      def parse_px(value)
        value.to_s[/\A\s*[+-]?\d+/].to_i
      end

      def px_to_pt(pixels)
        ((pixels * 3) + 2) / 4
      end

      def compute_font_width_and_space_count(expected_width)
        return [0, 0] unless expected_width.positive?

        space_count = (expected_width / 10.0).ceil.clamp(1, 1000)
        [expected_width.to_f / space_count / 2.0, space_count]
      end
    end
  end
end
