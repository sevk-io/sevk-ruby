# frozen_string_literal: true

require 'rouge'
require 'json'
require 'strscan'

require_relative 'document_parser'
require_relative 'html_document'
require_relative 'number_formatting'
require_relative 'render_limits'
require_relative 'style_helpers'
require_relative 'syntax_highlighting'
require_relative 'tag_scanner'
require_relative 'template_engine'

module Sevk
  module Markup
    class FontConfig
      attr_accessor :id, :name, :url

      def initialize(id: '', name: '', url: '')
        @id = id
        @name = name
        @url = url
      end
    end

    class EmailHeadSettings
      attr_accessor :title, :preview_text, :styles, :fonts, :lang, :dir

      def initialize
        @title = ''
        @preview_text = ''
        @styles = ''
        @fonts = []
        @lang = ''
        @dir = ''
      end
    end

    class Renderer
      include DocumentParser
      include HtmlDocument
      include NumberFormatting
      include RenderLimits
      include StyleHelpers
      include SyntaxHighlighting
      include TagScanner
      include TemplateEngine

      def initialize
        @head_settings = EmailHeadSettings.new
      end

      # Converts sevk markup into complete, email-compatible HTML.
      def render(markup)
        @head_settings = EmailHeadSettings.new
        parse_head_settings(markup)
        body_content = extract_body_content(markup)
        normalized = normalize_markup(body_content)
        processed = process_markup(normalized)
        generate_html(processed)
      end

      private

      def normalize_markup(content)
        result = content

        result = result.gsub(/<link(\s+(?:[\w-]+=(?:"[^"]*"|'[^']*')\s+)*)href=/i, '<sevk-link\1href=')
        result = result.gsub(%r{</link>}i, '</sevk-link>')

        result = "<mail><body>#{result}</body></mail>" unless result.match?(/<(?:sevk-email|email|mail)(?=[\s>])/i)

        result
      end

      def process_markup(content)
        @gap_rules = []
        @codeblock_budget = 0
        @scan_work = 0
        assert_markup_depth(content)

        result = process_tag(content, 'block') do |attrs, inner|
          process_block_tag(attrs, inner)
        end

        result = replace_self_closing(result, 'block', self_close_only: true) do |attrs_str|
          process_block_tag(parse_attributes(attrs_str))
        end
        assert_markup_depth(result)

        result = result.gsub(/<link(\s+(?:[\w-]+=(?:"[^"]*"|'[^']*')\s+)*)href=/i, '<sevk-link\1href=')
        result = result.gsub(%r{</link>}i, '</sevk-link>')

        # Section: padding and text-align go on td (Outlook-friendly), rest on outer table.
        result = process_tag(result, 'section') do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          td_style = {}
          td_style['padding'] = style.delete('padding') if style.key?('padding')
          td_style['text-align'] = style.delete('text-align') if style.key?('text-align')
          # Tables default to border-collapse:collapse via the global reset,
          # which disables border-radius. Flip to separate when any corner
          # radius is set so the rounded border actually renders.
          radius_keys = %w[
            border-radius border-top-left-radius border-top-right-radius
            border-bottom-left-radius border-bottom-right-radius
          ]
          style['border-collapse'] = 'separate' if radius_keys.any? { |key| style.key?(key) }

          [
            %(<table align="center" width="100%" border="0" cellPadding="0" ),
            %(cellSpacing="0" role="presentation" style="#{style_to_string(style)}">\n),
            "<tbody>\n",
            "<tr>\n",
            %(<td style="#{style_to_string(td_style)}">#{inner}</td>\n),
            "</tr>\n",
            "</tbody>\n",
            '</table>'
          ].join
        end

        result = process_tag(result, 'column') do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style['vertical-align'] ||= 'top'
          style_str = style_to_string(style)
          %(<td class="sevk-column" style="#{style_str}">#{inner}</td>)
        end

        row_counter = 0
        result = process_tag(result, 'row') do |attrs, inner|
          gap = attrs['gap'] || '0'
          style = extract_all_style_attributes(attrs)
          style.delete('gap')
          style_str = style_to_string(style)
          gap_px = gap.sub('px', '')
          gap_num = parse_px(gap_px)
          row_id = "sevk-row-#{row_counter}"
          row_counter += 1

          processed_inner = inner
          column_count = inner.scan('class="sevk-column"').length
          if column_count > 1
            equal_width = "#{(100 / column_count).to_i}%"
            processed_inner = processed_inner.gsub(/<td class="sevk-column" style="([^"]*)"/) do
              existing_style = Regexp.last_match(1)
              if existing_style.include?('width:')
                %(<td class="sevk-column" style="#{existing_style}")
              else
                %(<td class="sevk-column" style="width:#{equal_width};#{existing_style}")
              end
            end
          end

          if gap_num.positive?
            spacer_td = [
              %(</td><td class="sevk-gap" ),
              %(style="width:#{gap_px}px;min-width:#{gap_px}px" width="#{gap_px}"></td>),
              %(<td class="sevk-column")
            ].join
            processed_inner = processed_inner.gsub(%r{</td>\s*<td class="sevk-column"}, spacer_td)
            @gap_rules << [
              ".#{row_id} .sevk-gap{display:none !important;}",
              ".#{row_id} > tbody > tr > td.sevk-column{display:block !important;",
              "width:100% !important;margin-bottom:#{gap_px}px !important;}",
              ".#{row_id} > tbody > tr > td.sevk-column:last-of-type{margin-bottom:0 !important;}"
            ].join
          end

          [
            %(<table align="center" width="100%" border="0" cellPadding="0" ),
            %(cellSpacing="0" role="presentation" class="sevk-row-table #{row_id}" style="#{style_str}">\n),
            %(<tbody style="width:100%">\n),
            %(<tr style="width:100%">#{processed_inner}</tr>\n),
            "</tbody>\n",
            '</table>'
          ].join
        end

        result = process_tag(result, 'container') do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          td_style = {}
          table_style = {}

          visual_keys = %w[
            background-color background-image background-size background-position background-repeat
            border border-top border-right border-bottom border-left border-color border-width border-style
            border-radius border-top-left-radius border-top-right-radius
            border-bottom-left-radius border-bottom-right-radius
            padding padding-top padding-right padding-bottom padding-left
          ]
          style.each do |key, value|
            if visual_keys.include?(key)
              td_style[key] = value
            else
              table_style[key] = value
            end
          end

          has_border_radius = td_style['border-radius'] || td_style['border-top-left-radius'] ||
                              td_style['border-top-right-radius'] || td_style['border-bottom-left-radius'] ||
                              td_style['border-bottom-right-radius']
          table_style['border-collapse'] = 'separate' if has_border_radius

          if table_style['width'] && table_style['width'] != '100%' && table_style['width'] != 'auto'
            table_style['max-width'] ||= table_style['width']
            table_style['width'] = '100%'
          end

          table_style_str = style_to_string(table_style)
          td_style_str = style_to_string(td_style)
          # No `align="center"` on container: centering is opt-in via the
          # user's markup (e.g. `margin="0 auto"`). Editor preview and the
          # rendered email follow the same "no implicit centering" contract.
          [
            %(<table width="100%" border="0" cellPadding="0" cellSpacing="0" ),
            %(role="presentation" style="#{table_style_str}">\n),
            "<tbody>\n",
            %(<tr style="width:100%">\n),
            %(<td style="#{td_style_str}">#{inner}</td>\n),
            "</tr>\n",
            "</tbody>\n",
            '</table>'
          ].join
        end

        result = process_tag(result, 'heading') do |attrs, inner|
          level = attrs['level'].to_s.empty? ? '1' : attrs['level']
          style = extract_all_style_attributes(attrs)
          style['margin'] ||= '0'
          style_str = style_to_string(style)
          %(<h#{level} style="#{style_str}">#{inner}</h#{level}>)
        end

        result = process_tag(result, 'paragraph') do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style['margin'] ||= '0'
          style_str = style_to_string(style)
          %(<p style="#{style_str}">#{inner}</p>)
        end

        result = process_tag(result, 'text') do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          %(<span style="#{style_str}">#{inner}</span>)
        end

        result = process_tag(result, 'button') do |attrs, inner|
          process_button(attrs, inner)
        end

        result = result.gsub(%r{<image([^>]*)/?>}i) do
          attrs = parse_attributes(Regexp.last_match(1) || '')
          src = attrs['src'] || ''
          alt = attrs['alt'] || ''
          width = attrs['width']
          height = attrs['height']

          style = extract_all_style_attributes(attrs)
          style['vertical-align'] ||= 'middle'
          style['max-width'] ||= '100%'

          style_str = style_to_string(style)
          width_value = width.to_s.sub('px', '')
          height_value = height.to_s.sub('px', '')
          width_attr = width_value.empty? ? '' : %( width="#{width_value}")
          height_attr = height_value.empty? ? '' : %( height="#{height_value}")

          %(<img src="#{src}" alt="#{alt}"#{width_attr}#{height_attr} style="#{style_str}" />)
        end

        result = result.gsub(%r{<divider([^>]*)/?>}i) do
          attrs = parse_attributes(Regexp.last_match(1) || '')
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          class_str = class_attribute(attrs)
          %(<hr style="#{style_str}"#{class_str} />)
        end

        result = result.gsub(%r{</divider>}i, '')
        result = result.gsub(%r{</image>}i, '')

        result = process_tag(result, 'sevk-link') do |attrs, inner|
          href = attrs['href'].to_s.empty? ? '#' : attrs['href']
          target = attrs['target'].to_s.empty? ? '_blank' : attrs['target']
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          %(<a href="#{href}" target="#{target}" style="#{style_str}">#{inner}</a>)
        end

        result = process_tag(result, 'list') do |attrs, inner|
          list_type = attrs['type'] || 'unordered'
          tag = list_type == 'ordered' ? 'ol' : 'ul'
          style = extract_all_style_attributes(attrs)
          style['margin'] ||= '0'
          style['list-style-type'] = attrs['list-style-type'] if attrs['list-style-type']
          style_str = style_to_string(style)
          class_str = class_attribute(attrs)
          %(<#{tag} style="#{style_str}"#{class_str}>#{inner}</#{tag}>)
        end

        result = process_tag(result, 'li') do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          class_str = class_attribute(attrs)
          %(<li style="#{style_str}"#{class_str}>#{inner}</li>)
        end

        result = process_tag(result, 'codeblock') do |attrs, inner|
          process_codeblock(attrs, inner)
        end

        stray_closing_tags = %w[container section row column heading paragraph text button sevk-link]
        stray_closing_tags.each do |tag|
          result = result.gsub(%r{</#{tag}>}i, '')
        end

        wrapper_patterns = [
          /<sevk-email[^>]*>/i, %r{</sevk-email>}i,
          /<sevk-body[^>]*>/i, %r{</sevk-body>}i,
          /<email[^>]*>/i, %r{</email>}i,
          /<mail[^>]*>/i, %r{</mail>}i,
          /<body[^>]*>/i, %r{</body>}i
        ]
        wrapper_patterns.each do |pattern|
          result = result.gsub(pattern, '')
        end

        result.strip
      end

      # Outlook button padding hack ported from react-email's Button component
      # (https://github.com/resend/react-email/blob/main/packages/components/src/button.tsx).
      # Uses mso-padding-alt:0, hairspace runs scaled by mso-font-width, and
      # mso-text-raise to get Outlook to honour horizontal/vertical padding.
      def process_button(attrs, inner)
        href = attrs['href'].to_s.empty? ? '#' : attrs['href']
        style = extract_all_style_attributes(attrs)

        padding_top, padding_right, padding_bottom, padding_left = parse_padding(style)

        y = padding_top + padding_bottom
        text_raise = px_to_pt(y)

        pl_font_width, pl_space_count = compute_font_width_and_space_count(padding_left)
        pr_font_width, pr_space_count = compute_font_width_and_space_count(padding_right)

        button_style = {
          'line-height' => '100%',
          'text-decoration' => 'none',
          'display' => 'inline-block',
          'max-width' => '100%',
          'mso-padding-alt' => '0px'
        }

        button_style.merge!(style)

        button_style['padding-top'] = "#{padding_top}px"
        button_style['padding-right'] = "#{padding_right}px"
        button_style['padding-bottom'] = "#{padding_bottom}px"
        button_style['padding-left'] = "#{padding_left}px"

        style_str = style_to_string(button_style)

        left_mso_spaces = '&#8202;' * pl_space_count
        right_mso_spaces = '&#8202;' * pr_space_count

        [
          %(<a href="#{href}" target="_blank" style="#{style_str}">),
          %(<!--[if mso]><i style="mso-font-width:#{(pl_font_width * 100).round}%;),
          %(mso-text-raise:#{text_raise}" hidden>#{left_mso_spaces}</i><![endif]-->),
          %(<span style="max-width:100%;display:inline-block;line-height:120%;),
          %(mso-padding-alt:0px;mso-text-raise:#{px_to_pt(padding_bottom)}">#{inner}</span>),
          %(<!--[if mso]><i style="mso-font-width:#{(pr_font_width * 100).round}%" hidden>),
          %(#{right_mso_spaces}&#8203;</i><![endif]--></a>)
        ].join
      end

      def process_tag(content, tag_name, &processor)
        result = content
        patterns = tag_patterns(tag_name)

        MAX_TAG_ITERATIONS.times do
          charge_scan_work(result.bytesize)
          replacements = collect_replacements(result, patterns, &processor)
          break if replacements.empty?

          rebuilt = rebuild_result(result, replacements)
          break if rebuilt == result

          result = rebuilt
        end

        result
      end

      def collect_replacements(result, patterns, &processor)
        scanner = StringScanner.new(result)
        replacements = []
        consumed_until = 0

        while scanner.skip_until(patterns.open)
          start = scanner.pos - scanner.matched_size
          next if start < consumed_until

          attrs_str = scanner[1]
          inner_start = scanner.pos
          close_pos = find_close(result, patterns, inner_start)
          charge_scan_work((close_pos || result.bytesize) - inner_start)
          next unless close_pos

          inner = result.byteslice(inner_start, close_pos - inner_start)
          next if inner.match?(patterns.nested)

          consumed_until = close_pos + patterns.close_length
          replacements << [start, consumed_until, processor.call(parse_attributes(attrs_str), inner)]
        end

        replacements
      end

      def find_close(result, patterns, inner_start)
        scanner = StringScanner.new(result)
        scanner.pos = inner_start
        scanner.skip_until(patterns.close) ? scanner.pos - patterns.close_length : nil
      end

      def rebuild_result(result, replacements)
        rebuilt = +''
        cursor = 0
        replacements.each do |r_start, r_end, r_text|
          rebuilt << result.byteslice(cursor, r_start - cursor) << r_text
          cursor = r_end
          if rebuilt.bytesize > MAX_RENDER_OUTPUT
            raise ArgumentError, "Email markup expands beyond the maximum size of #{MAX_RENDER_OUTPUT} bytes"
          end
        end
        rebuilt << result.byteslice(cursor, result.bytesize - cursor)
      end
    end

    # Converts sevk markup into complete, email-compatible HTML.
    def self.render(markup)
      Renderer.new.render(markup)
    end
  end
end
