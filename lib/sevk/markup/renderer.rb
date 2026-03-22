# frozen_string_literal: true

require "rouge"
require "json"

module Sevk
  module Markup
    # Font configuration
    class FontConfig
      attr_accessor :id, :name, :url

      def initialize(id: "", name: "", url: "")
        @id = id
        @name = name
        @url = url
      end
    end

    # Head settings for email generation
    class EmailHeadSettings
      attr_accessor :title, :preview_text, :styles, :fonts, :lang, :dir

      def initialize
        @title = ""
        @preview_text = ""
        @styles = ""
        @fonts = []
        @lang = ""
        @dir = ""
      end
    end

    # Parsed email content
    class ParsedEmailContent
      attr_accessor :body, :head_settings

      def initialize
        @body = ""
        @head_settings = EmailHeadSettings.new
      end
    end

    # Sevk Markup Renderer
    # Converts Sevk markup to email-compatible HTML using regex-based parsing (like Node.js)
    class Renderer
      def initialize
        @head_settings = EmailHeadSettings.new
      end

      def render(markup)
        # Parse head settings from markup
        parse_head_settings(markup)

        # Extract clean body content (strips <mail>/<head> wrapper tags)
        body_content = extract_body_content(markup)

        # Normalize markup
        normalized = normalize_markup(body_content)

        # Process markup using regex
        processed = process_markup(normalized)

        generate_html(processed)
      end

      private

      def extract_body_content(markup)
        if markup.include?("<mail") || markup.include?("<email")
          if (match = markup.match(/<body[^>]*>([\s\S]*?)<\/body>/i))
            return match[1].strip
          end
        end
        markup
      end

      def normalize_markup(content)
        result = content

        # Replace <link> with <sevk-link>
        if result.include?("<link")
          result = result.gsub(/<link\s+href=/i, "<sevk-link href=")
          result = result.gsub("</link>", "</sevk-link>")
        end

        unless result.include?("<sevk-email") || result.include?("<email") || result.include?("<mail")
          result = "<mail><body>#{result}</body></mail>"
        end

        result
      end

      def parse_head_settings(markup)
        # Parse lang and dir from <mail> or <email> root tag
        if (root_match = markup.match(/<(?:email|mail)([^>]*)>/i))
          root_attrs = root_match[1]
          if (lang_match = root_attrs.match(/lang=["']([^"']*)["']/i))
            @head_settings.lang = lang_match[1]
          end
          if (dir_match = root_attrs.match(/dir=["']([^"']*)["']/i))
            @head_settings.dir = dir_match[1]
          end
        end

        # Extract title
        if (match = markup.match(/<title[^>]*>([\s\S]*?)<\/title>/i))
          @head_settings.title = match[1].strip
        end

        # Extract preview
        if (match = markup.match(/<preview[^>]*>([\s\S]*?)<\/preview>/i))
          @head_settings.preview_text = match[1].strip
        end

        # Extract styles
        if (match = markup.match(/<style[^>]*>([\s\S]*?)<\/style>/i))
          @head_settings.styles = match[1].strip
        end

        # Extract fonts
        markup.scan(/<font[^>]*name=["']([^"']*)["'][^>]*url=["']([^"']*)["'][^>]*\/?>/i).each_with_index do |(name, url), i|
          @head_settings.fonts << FontConfig.new(id: "font-#{i}", name: name, url: url)
        end
      end

      def process_markup(content)
        result = content

        # Convert <link> to <sevk-link>
        if result.include?("<link")
          result = result.gsub(/<link\s+href=/i, "<sevk-link href=")
          result = result.gsub("</link>", "</sevk-link>")
        end

        # Process block tags (before other tags)
        result = process_tag(result, "block") do |attrs, inner|
          process_block_tag(attrs, inner)
        end

        # Process self-closing block tags
        result = result.gsub(/<block([^>]*)\/?\s*>/i) do
          attrs = parse_attributes(Regexp.last_match(1) || "")
          process_block_tag(attrs)
        end

        # Process section tags
        result = process_tag(result, "section") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          %(<table align="center" width="100%" border="0" cellPadding="0" cellSpacing="0" role="presentation" style="#{style_str}">
<tbody>
<tr>
<td>#{inner}</td>
</tr>
</tbody>
</table>)
        end

        # Process column tags (before rows, so row can count them)
        result = process_tag(result, "column") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style["vertical-align"] ||= "top"
          style_str = style_to_string(style)
          %(<td class="sevk-column" style="#{style_str}">#{inner}</td>)
        end

        # Process row tags
        row_counter = 0
        result = process_tag(result, "row") do |attrs, inner|
          gap = attrs["gap"] || "0"
          style = extract_all_style_attributes(attrs)
          style.delete("gap")
          style_str = style_to_string(style)
          gap_px = gap.gsub("px", "")
          gap_num = gap_px.to_i
          row_id = "sevk-row-#{row_counter}"
          row_counter += 1

          # Assign equal widths to columns if more than one
          processed_inner = inner
          column_count = inner.scan(/class="sevk-column"/).length
          if column_count > 1
            equal_width = "#{(100 / column_count).to_i}%"
            processed_inner = processed_inner.gsub(/<td class="sevk-column" style="([^"]*)"/) do
              existing_style = Regexp.last_match(1)
              if existing_style.include?("width:")
                %(<td class="sevk-column" style="#{existing_style}")
              else
                %(<td class="sevk-column" style="width:#{equal_width};#{existing_style}")
              end
            end
          end

          gap_style = gap_num > 0 ? %(<style>@media only screen and (max-width:479px){.#{row_id} > tbody > tr > td{margin-bottom:#{gap_px}px !important;padding-left:0 !important;padding-right:0 !important;}.#{row_id} > tbody > tr > td:last-child{margin-bottom:0 !important;}}</style>) : ""
          %(#{gap_style}<table class="sevk-row-table #{row_id}" align="center" width="100%" border="0" cellPadding="0" cellSpacing="0" role="presentation" style="#{style_str}">
<tbody style="width:100%">
<tr style="width:100%">#{processed_inner}</tr>
</tbody>
</table>)
        end

        # Process container tags
        result = process_tag(result, "container") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          td_style = {}
          table_style = {}

          # Visual styles go on <td>, layout styles stay on <table>
          visual_keys = %w[
            background-color background-image background-size background-position background-repeat
            border border-top border-right border-bottom border-left border-color border-width border-style
            border-radius border-top-left-radius border-top-right-radius border-bottom-left-radius border-bottom-right-radius
            padding padding-top padding-right padding-bottom padding-left
          ]
          style.each do |key, value|
            if visual_keys.include?(key)
              td_style[key] = value
            else
              table_style[key] = value
            end
          end

          # Add border-collapse: separate when border-radius is used
          has_border_radius = td_style["border-radius"] || td_style["border-top-left-radius"] ||
            td_style["border-top-right-radius"] || td_style["border-bottom-left-radius"] ||
            td_style["border-bottom-right-radius"]
          table_style["border-collapse"] = "separate" if has_border_radius

          # Make fixed widths responsive: width becomes max-width, width set to 100%
          if table_style["width"] && table_style["width"] != "100%" && table_style["width"] != "auto"
            table_style["max-width"] ||= table_style["width"]
            table_style["width"] = "100%"
          end

          table_style_str = style_to_string(table_style)
          td_style_str = style_to_string(td_style)
          %(<table align="center" width="100%" border="0" cellPadding="0" cellSpacing="0" role="presentation" style="#{table_style_str}">
<tbody>
<tr style="width:100%">
<td style="#{td_style_str}">#{inner}</td>
</tr>
</tbody>
</table>)
        end

        # Process heading tags
        result = process_tag(result, "heading") do |attrs, inner|
          level = attrs["level"] || "1"
          style = extract_all_style_attributes(attrs)
          style['margin'] ||= '0'
          style_str = style_to_string(style)
          %(<h#{level} style="#{style_str}">#{inner}</h#{level}>)
        end

        # Process paragraph tags
        result = process_tag(result, "paragraph") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style['margin'] ||= '0'
          style_str = style_to_string(style)
          %(<p style="#{style_str}">#{inner}</p>)
        end

        # Process text tags
        result = process_tag(result, "text") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          %(<span style="#{style_str}">#{inner}</span>)
        end

        # Process button tags with MSO compatibility
        result = process_tag(result, "button") do |attrs, inner|
          process_button(attrs, inner)
        end

        # Process image tags
        result = result.gsub(/<image([^>]*)\/?>/i) do
          attrs = parse_attributes(Regexp.last_match(1) || "")
          src = attrs["src"] || ""
          alt = attrs["alt"] || ""
          width = attrs["width"]
          height = attrs["height"]

          style = extract_all_style_attributes(attrs)
          style["vertical-align"] ||= "middle"
          style["max-width"] ||= "100%"
          style["outline"] ||= "none"
          style["border"] ||= "none"
          style["text-decoration"] ||= "none"

          style_str = style_to_string(style)
          width_attr = width ? %( width="#{width.to_s.gsub('px', '')}") : ""
          height_attr = height ? %( height="#{height.to_s.gsub('px', '')}") : ""

          %(<img src="#{src}" alt="#{alt}"#{width_attr}#{height_attr} style="#{style_str}" />)
        end

        # Process divider tags
        result = result.gsub(/<divider([^>]*)\/?>/i) do
          attrs = parse_attributes(Regexp.last_match(1) || "")
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          class_attr = attrs["class"] || attrs["className"]
          class_str = class_attr ? %( class="#{class_attr}") : ""
          %(<hr style="#{style_str}"#{class_str} />)
        end

        # Remove stray </divider> closing tags
        result = result.gsub(%r{</divider>}i, "")

        # Process link tags
        result = process_tag(result, "sevk-link") do |attrs, inner|
          href = attrs["href"] || "#"
          target = attrs["target"] || "_blank"
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          %(<a href="#{href}" target="#{target}" style="#{style_str}">#{inner}</a>)
        end

        # Process list tags
        result = process_tag(result, "list") do |attrs, inner|
          list_type = attrs["type"] || "unordered"
          tag = list_type == "ordered" ? "ol" : "ul"
          style = extract_all_style_attributes(attrs)
          style['margin'] ||= '0'
          style["list-style-type"] = attrs["list-style-type"] if attrs["list-style-type"]
          style_str = style_to_string(style)
          class_attr = attrs["class"] || attrs["className"]
          class_str = class_attr ? %( class="#{class_attr}") : ""
          %(<#{tag} style="#{style_str}"#{class_str}>#{inner}</#{tag}>)
        end

        # Process list item tags
        result = process_tag(result, "li") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          class_attr = attrs["class"] || attrs["className"]
          class_str = class_attr ? %( class="#{class_attr}") : ""
          %(<li style="#{style_str}"#{class_str}>#{inner}</li>)
        end

        # Process codeblock tags
        result = process_tag(result, "codeblock") do |attrs, inner|
          process_codeblock(attrs, inner)
        end

        # Clean up stray Sevk closing tags
        stray_closing_tags = %w[container section row column heading paragraph text button sevk-link]
        stray_closing_tags.each do |tag|
          result = result.gsub(%r{</#{tag}>}i, "")
        end

        # Clean up wrapper tags
        wrapper_patterns = [
          /<sevk-email[^>]*>/i, /<\/sevk-email>/i,
          /<sevk-body[^>]*>/i, /<\/sevk-body>/i,
          /<email[^>]*>/i, /<\/email>/i,
          /<mail[^>]*>/i, /<\/mail>/i,
          /<body[^>]*>/i, /<\/body>/i
        ]
        wrapper_patterns.each do |pattern|
          result = result.gsub(pattern, "")
        end

        result.strip
      end

      def process_button(attrs, inner)
        href = attrs["href"] || "#"
        style = extract_all_style_attributes(attrs)

        # Parse padding
        padding_top, padding_right, padding_bottom, padding_left = parse_padding(style)

        y = padding_top + padding_bottom
        text_raise = px_to_pt(y)

        pl_font_width, pl_space_count = compute_font_width_and_space_count(padding_left)
        pr_font_width, pr_space_count = compute_font_width_and_space_count(padding_right)

        button_style = {
          "line-height" => "100%",
          "text-decoration" => "none",
          "display" => "inline-block",
          "max-width" => "100%",
          "mso-padding-alt" => "0px"
        }

        # Merge with extracted styles
        button_style.merge!(style)

        # Override padding with parsed values
        button_style["padding-top"] = "#{padding_top}px"
        button_style["padding-right"] = "#{padding_right}px"
        button_style["padding-bottom"] = "#{padding_bottom}px"
        button_style["padding-left"] = "#{padding_left}px"

        style_str = style_to_string(button_style)

        left_mso_spaces = "&#8202;" * pl_space_count
        right_mso_spaces = "&#8202;" * pr_space_count

        %(<a href="#{href}" target="_blank" style="#{style_str}"><!--[if mso]><i style="mso-font-width:#{(pl_font_width * 100).round}%;mso-text-raise:#{text_raise}" hidden>#{left_mso_spaces}</i><![endif]--><span style="max-width:100%;display:inline-block;line-height:120%;mso-padding-alt:0px;mso-text-raise:#{px_to_pt(padding_bottom)}">#{inner}</span><!--[if mso]><i style="mso-font-width:#{(pr_font_width * 100).round}%" hidden>#{right_mso_spaces}&#8203;</i><![endif]--></a>)
      end

      # One Dark theme token-to-inline-style mapping
      ONE_DARK_THEME = {
        "Comment" => { "color" => "#5c6370", "font-style" => "italic" },
        "Comment.Single" => { "color" => "#5c6370", "font-style" => "italic" },
        "Comment.Multiline" => { "color" => "#5c6370", "font-style" => "italic" },
        "Comment.Preproc" => { "color" => "#5c6370", "font-style" => "italic" },
        "Comment.Doc" => { "color" => "#5c6370", "font-style" => "italic" },
        "Comment.Special" => { "color" => "#5c6370", "font-style" => "italic" },
        "Keyword" => { "color" => "#c678dd" },
        "Keyword.Constant" => { "color" => "#c678dd" },
        "Keyword.Declaration" => { "color" => "#c678dd" },
        "Keyword.Namespace" => { "color" => "#c678dd" },
        "Keyword.Pseudo" => { "color" => "#c678dd" },
        "Keyword.Reserved" => { "color" => "#c678dd" },
        "Keyword.Type" => { "color" => "#c678dd" },
        "Literal.String" => { "color" => "#98c379" },
        "Literal.String.Affix" => { "color" => "#98c379" },
        "Literal.String.Backtick" => { "color" => "#98c379" },
        "Literal.String.Char" => { "color" => "#98c379" },
        "Literal.String.Doc" => { "color" => "#98c379" },
        "Literal.String.Double" => { "color" => "#98c379" },
        "Literal.String.Escape" => { "color" => "#d19a66" },
        "Literal.String.Heredoc" => { "color" => "#98c379" },
        "Literal.String.Interpol" => { "color" => "#98c379" },
        "Literal.String.Other" => { "color" => "#98c379" },
        "Literal.String.Regex" => { "color" => "#98c379" },
        "Literal.String.Single" => { "color" => "#98c379" },
        "Literal.String.Symbol" => { "color" => "#e06c75" },
        "Literal.Number" => { "color" => "#d19a66" },
        "Literal.Number.Bin" => { "color" => "#d19a66" },
        "Literal.Number.Float" => { "color" => "#d19a66" },
        "Literal.Number.Hex" => { "color" => "#d19a66" },
        "Literal.Number.Integer" => { "color" => "#d19a66" },
        "Literal.Number.Oct" => { "color" => "#d19a66" },
        "Name.Function" => { "color" => "#61afef" },
        "Name.Function.Magic" => { "color" => "#61afef" },
        "Name.Builtin" => { "color" => "#61afef" },
        "Name.Builtin.Pseudo" => { "color" => "#e06c75" },
        "Name.Variable" => { "color" => "#e06c75" },
        "Name.Variable.Class" => { "color" => "#e06c75" },
        "Name.Variable.Global" => { "color" => "#e06c75" },
        "Name.Variable.Instance" => { "color" => "#e06c75" },
        "Name.Variable.Magic" => { "color" => "#e06c75" },
        "Name.Class" => { "color" => "#d19a66" },
        "Name.Constant" => { "color" => "#d19a66" },
        "Name.Decorator" => { "color" => "#61afef" },
        "Name.Attribute" => { "color" => "#d19a66" },
        "Name.Tag" => { "color" => "#e06c75" },
        "Name.Namespace" => { "color" => "#d19a66" },
        "Operator" => { "color" => "#61afef" },
        "Operator.Word" => { "color" => "#c678dd" },
        "Punctuation" => { "color" => "#abb2bf" },
        "Generic.Deleted" => { "color" => "#e06c75" },
        "Generic.Inserted" => { "color" => "#98c379" },
        "Generic.Heading" => { "color" => "#61afef", "font-weight" => "bold" },
        "Generic.Subheading" => { "color" => "#61afef" },
        "Generic.Emph" => { "font-style" => "italic" },
        "Generic.Strong" => { "font-weight" => "bold" },
      }.freeze

      def process_codeblock(attrs, inner)
        language = attrs["language"] || "text"
        custom_style = extract_all_style_attributes(attrs)

        code = inner.strip

        # Try to find a Rouge lexer for the language
        lexer = begin
          Rouge::Lexer.find(language)&.new
        rescue StandardError
          nil
        end

        # Base pre styles (One Dark)
        base_style = {
          "background-color" => "#282c34",
          "color" => "#abb2bf",
          "font-family" => "'Fira Code', 'Fira Mono', Menlo, Consolas, 'DejaVu Sans Mono', monospace",
          "font-size" => "13px",
          "direction" => "ltr",
          "text-align" => "left",
          "white-space" => "pre",
          "word-spacing" => "normal",
          "word-break" => "normal",
          "line-height" => "1.5",
          "tab-size" => "2",
          "hyphens" => "none",
          "padding" => "1em",
          "margin" => "0.5em 0",
          "overflow" => "auto",
          "border-radius" => "0.3em",
          "width" => "100%",
          "box-sizing" => "border-box"
        }
        base_style.merge!(custom_style)

        if lexer.nil?
          # Fallback: plain pre/code with no highlighting
          style_str = style_to_string(base_style)
          escaped = code.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
          return %(<pre style="#{style_str}"><code>#{escaped}</code></pre>)
        end

        # Tokenize and highlight
        tokens = lexer.lex(code)
        lines = build_highlighted_lines(tokens)

        lines_html = lines.map do |line_tokens|
          spans = line_tokens.map { |tok_type, tok_text| render_rouge_token(tok_type, tok_text) }.join
          %(<p style="margin:0;min-height:1em">#{spans}</p>)
        end

        style_str = style_to_string(base_style)
        %(<pre style="#{style_str}"><code>#{lines_html.join}</code></pre>)
      end

      def build_highlighted_lines(tokens)
        lines = [[]]
        tokens.each do |tok_type, tok_text|
          parts = tok_text.split(/(\n)/, -1)
          parts.each_with_index do |part, i|
            if part == "\n"
              lines << []
            elsif !part.empty?
              lines.last << [tok_type, part]
            end
          end
        end
        lines
      end

      def render_rouge_token(tok_type, text)
        escaped = text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
        # Replace spaces with non-breaking space + zero-width joiner + zero-width space for email safety
        escaped = escaped.gsub(" ", "\u00A0\u200D\u200B")

        styles = resolve_token_styles(tok_type)
        if styles.empty?
          escaped
        else
          style_str = styles.map { |k, v| "#{k}:#{v}" }.join(";")
          %(<span style="#{style_str}">#{escaped}</span>)
        end
      end

      def resolve_token_styles(tok_type)
        # Walk up the token hierarchy to find a matching theme entry
        # e.g., Token::Literal::String::Double -> "Literal.String.Double" -> "Literal.String" -> ...
        qualname = tok_type.qualname
        loop do
          return ONE_DARK_THEME[qualname].dup if ONE_DARK_THEME.key?(qualname)

          dot_index = qualname.rindex(".")
          break unless dot_index

          qualname = qualname[0...dot_index]
        end

        # Check base token name
        return ONE_DARK_THEME[qualname].dup if ONE_DARK_THEME.key?(qualname)

        {}
      end

      def truthy?(val)
        return false if val.nil?
        return false if val == false
        return false if val == 0
        return false if val.is_a?(String) && val.empty?
        return false if val.is_a?(Array) && val.empty?

        true
      end

      def evaluate_condition(expr, config)
        trimmed = expr.strip

        # OR: split on ||, return true if any part is true
        if trimmed.include?('||')
          return trimmed.split('||').any? { |part| evaluate_condition(part, config) }
        end

        # AND: split on &&, return true if all parts are true
        if trimmed.include?('&&')
          return trimmed.split('&&').all? { |part| evaluate_condition(part, config) }
        end

        # Equality: key == "value"
        if (eq_match = trimmed.match(/^(\w+)\s*==\s*"([^"]*)"$/))
          return (config[eq_match[1]] || '').to_s == eq_match[2]
        end

        # Inequality: key != "value"
        if (neq_match = trimmed.match(/^(\w+)\s*!=\s*"([^"]*)"$/))
          return (config[neq_match[1]] || '').to_s != neq_match[2]
        end

        # Simple truthy check
        truthy?(config[trimmed])
      end

      def render_template(template, config)
        result = template.dup

        # Process #each loops
        result = result.gsub(/\{%#each\s+(\w+)\s+as\s+(\w+)%\}([\s\S]*?)\{%\/each%\}/) do
          key = Regexp.last_match(1)
          alias_name = Regexp.last_match(2)
          body = Regexp.last_match(3)
          arr = config[key]
          if arr.is_a?(Array)
            arr.map do |item|
              iteration = body.dup
              if item.is_a?(Hash)
                item.each do |prop, val|
                  iteration = iteration.gsub(/\{%#{Regexp.escape(alias_name)}\.#{Regexp.escape(prop)}(?:\s*\?\?\s*([^%]*?))?\s*%\}/) do
                    fallback = Regexp.last_match(1)
                    truthy?(val) ? val.to_s : (fallback ? fallback.strip : '')
                  end
                end
              end
              # Replace bare alias reference
              iteration = iteration.gsub(/\{%#{Regexp.escape(alias_name)}(?:\s*\?\?\s*([^%]*?))?\s*%\}/) do
                fallback = Regexp.last_match(1)
                truthy?(item) ? item.to_s : (fallback ? fallback.strip : '')
              end
              iteration
            end.join
          else
            ''
          end
        end

        # Process nested #if conditionals (innermost first)
        loop do
          matched = false
          result = result.gsub(/\{%#if\s+([^%]+)%\}((?:(?!\{%#if\s)[\s\S])*?)\{%\/if%\}/) do
            matched = true
            condition = Regexp.last_match(1)
            body = Regexp.last_match(2)
            if body.include?('{%else%}')
              parts = body.split('{%else%}', 2)
              evaluate_condition(condition, config) ? parts[0] : parts[1]
            else
              evaluate_condition(condition, config) ? body : ''
            end
          end
          break unless matched
        end

        # Process variable injection with fallback
        result = result.gsub(/\{%(\w+)(?:\s*\?\?\s*([^%]*?))?\s*%\}/) do
          key = Regexp.last_match(1)
          fallback = Regexp.last_match(2)
          val = config[key]
          truthy?(val) ? val.to_s : (fallback ? fallback.strip : '')
        end

        result
      end

      def process_block_tag(attrs, inner = '')
        template = inner.strip.empty? ? (attrs['template'] || '') : inner.strip
        return '' if template.empty?

        config_str = (attrs['config'] || '{}').gsub("'", '"').gsub('&quot;', '"').gsub('&amp;', '&')
        config = begin
          JSON.parse(config_str)
        rescue StandardError
          {}
        end
        render_template(template, config)
      end

      def parse_padding(style)
        if style["padding"]
          parts = style["padding"].split
          case parts.length
          when 1
            val = parse_px(parts[0])
            [val, val, val, val]
          when 2
            vertical = parse_px(parts[0])
            horizontal = parse_px(parts[1])
            [vertical, horizontal, vertical, horizontal]
          when 4
            [parse_px(parts[0]), parse_px(parts[1]), parse_px(parts[2]), parse_px(parts[3])]
          else
            [0, 0, 0, 0]
          end
        else
          [
            parse_px(style["padding-top"] || "0"),
            parse_px(style["padding-right"] || "0"),
            parse_px(style["padding-bottom"] || "0"),
            parse_px(style["padding-left"] || "0")
          ]
        end
      end

      def parse_px(s)
        s.to_s.gsub("px", "").to_i
      end

      def px_to_pt(px)
        (px * 3) / 4
      end

      def compute_font_width_and_space_count(expected_width)
        return [0, 0] if expected_width == 0

        smallest_space_count = 0
        max_font_width = 5.0

        loop do
          required_font_width = if smallest_space_count > 0
                                  expected_width.to_f / smallest_space_count / 2.0
                                else
                                  Float::INFINITY
                                end

          return [required_font_width, smallest_space_count] if required_font_width <= max_font_width

          smallest_space_count += 1
        end
      end

      def process_tag(content, tag_name)
        result = content
        open_pattern = /<#{tag_name}([^>]*)>/i
        close_tag = "</#{tag_name}>"
        open_tag_start = "<#{tag_name}"

        max_iterations = 10_000
        iterations = 0

        while iterations < max_iterations
          iterations += 1

          # Find all opening tags
          matches = result.to_enum(:scan, open_pattern).map { Regexp.last_match }
          break if matches.empty?

          processed = false

          # Find the innermost tag (one that has no nested same tags)
          matches.reverse_each do |match|
            start = match.begin(0)
            inner_start = match.end(0)
            attrs_str = match[1]

            # Find the next close tag after this opening tag (case-insensitive)
            close_match = result.match(Regexp.new("<\\/#{tag_name}>", Regexp::IGNORECASE), inner_start)
            next unless close_match

            close_pos = close_match.begin(0)
            inner = result[inner_start...close_pos]

            # Check if there's another opening tag inside (case-insensitive)
            next if inner.match?(Regexp.new("<#{tag_name}", Regexp::IGNORECASE))

            # This is an innermost tag, process it
            attrs = parse_attributes(attrs_str)
            replacement = yield(attrs, inner)
            end_pos = close_pos + close_tag.length

            result = result[0...start] + replacement + result[end_pos..]
            processed = true
            break
          end

          break unless processed
        end

        result
      end

      def parse_attributes(attrs_str)
        attrs = {}
        attrs_str.scan(/([\w-]+)=(?:"([^"]*)"|'([^']*)')/) do |key, dq_val, sq_val|
          attrs[key] = dq_val.nil? || dq_val.empty? ? (sq_val || '') : dq_val
        end
        attrs
      end

      def extract_all_style_attributes(attrs)
        style = {}

        # Typography attributes
        if attrs["text-color"]
          style["color"] = attrs["text-color"]
        elsif attrs["color"]
          style["color"] = attrs["color"]
        end
        style["background-color"] = attrs["background-color"] if attrs["background-color"]
        style["font-size"] = attrs["font-size"] if attrs["font-size"]
        style["font-family"] = attrs["font-family"] if attrs["font-family"]
        style["font-weight"] = attrs["font-weight"] if attrs["font-weight"]
        style["line-height"] = attrs["line-height"] if attrs["line-height"]
        style["text-align"] = attrs["text-align"] if attrs["text-align"]
        style["text-decoration"] = attrs["text-decoration"] if attrs["text-decoration"]

        # Dimensions
        style["width"] = attrs["width"] if attrs["width"]
        style["height"] = attrs["height"] if attrs["height"]
        style["max-width"] = attrs["max-width"] if attrs["max-width"]
        style["max-height"] = attrs["max-height"] if attrs["max-height"]
        style["min-width"] = attrs["min-width"] if attrs["min-width"]
        style["min-height"] = attrs["min-height"] if attrs["min-height"]

        # Spacing - Padding
        if attrs["padding"]
          style["padding"] = attrs["padding"]
        else
          style["padding-top"] = attrs["padding-top"] if attrs["padding-top"]
          style["padding-right"] = attrs["padding-right"] if attrs["padding-right"]
          style["padding-bottom"] = attrs["padding-bottom"] if attrs["padding-bottom"]
          style["padding-left"] = attrs["padding-left"] if attrs["padding-left"]
        end

        # Spacing - Margin
        if attrs["margin"]
          style["margin"] = attrs["margin"]
        else
          style["margin-top"] = attrs["margin-top"] if attrs["margin-top"]
          style["margin-right"] = attrs["margin-right"] if attrs["margin-right"]
          style["margin-bottom"] = attrs["margin-bottom"] if attrs["margin-bottom"]
          style["margin-left"] = attrs["margin-left"] if attrs["margin-left"]
        end

        # Borders
        if attrs["border"]
          style["border"] = attrs["border"]
        else
          style["border-top"] = attrs["border-top"] if attrs["border-top"]
          style["border-right"] = attrs["border-right"] if attrs["border-right"]
          style["border-bottom"] = attrs["border-bottom"] if attrs["border-bottom"]
          style["border-left"] = attrs["border-left"] if attrs["border-left"]
          style["border-color"] = attrs["border-color"] if attrs["border-color"]
          style["border-width"] = attrs["border-width"] if attrs["border-width"]
          style["border-style"] = attrs["border-style"] if attrs["border-style"]
        end

        # Border Radius
        if attrs["border-radius"]
          style["border-radius"] = attrs["border-radius"]
        else
          style["border-top-left-radius"] = attrs["border-top-left-radius"] if attrs["border-top-left-radius"]
          style["border-top-right-radius"] = attrs["border-top-right-radius"] if attrs["border-top-right-radius"]
          style["border-bottom-left-radius"] = attrs["border-bottom-left-radius"] if attrs["border-bottom-left-radius"]
          style["border-bottom-right-radius"] = attrs["border-bottom-right-radius"] if attrs["border-bottom-right-radius"]
        end

        # Background image
        if attrs["background-image"]
          style["background-image"] = "url('#{attrs["background-image"]}')"
          style["background-size"] = attrs["background-size"] || "cover"
          style["background-position"] = attrs["background-position"] || "center"
          style["background-repeat"] = attrs["background-repeat"] || "no-repeat"
        else
          style["background-size"] = attrs["background-size"] if attrs["background-size"]
          style["background-position"] = attrs["background-position"] if attrs["background-position"]
          style["background-repeat"] = attrs["background-repeat"] if attrs["background-repeat"]
        end

        style
      end

      def style_to_string(style)
        style.map { |k, v| "#{k}:#{v}" }.join(";")
      end

      def generate_html(content)
        lang = @head_settings.lang.empty? ? "en" : @head_settings.lang
        dir = @head_settings.dir.empty? ? "ltr" : @head_settings.dir

        title = @head_settings.title.empty? ? "" : "<title>#{@head_settings.title}</title>"

        font_links = @head_settings.fonts.map do |font|
          %(<link href="#{CGI.escapeHTML(font.url)}" rel="stylesheet" type="text/css" />)
        end.join("\n")

        styles = @head_settings.styles.empty? ? "" : %(<style type="text/css">#{@head_settings.styles}</style>)

        preview_text = ""
        unless @head_settings.preview_text.empty?
          preview_text = %(<div style="display:none;font-size:1px;color:#ffffff;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">#{CGI.escapeHTML(@head_settings.preview_text)}</div>)
        end

        <<~HTML
          <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
          <html lang="#{lang}" dir="#{dir}" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
          <head>
          <meta content="text/html; charset=UTF-8" http-equiv="Content-Type"/>
          <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
          <meta name="x-apple-disable-message-reformatting"/>
          <meta content="IE=edge" http-equiv="X-UA-Compatible"/>
          <meta name="format-detection" content="telephone=no,address=no,email=no,date=no,url=no"/>
          <!--[if mso]>
          <noscript>
          <xml>
          <o:OfficeDocumentSettings>
          <o:AllowPNG/>
          <o:PixelsPerInch>96</o:PixelsPerInch>
          </o:OfficeDocumentSettings>
          </xml>
          </noscript>
          <![endif]-->
          <style type="text/css">
          #outlook a { padding: 0; }
          body { margin: 0; padding: 0; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
          table, td { border-collapse: collapse; mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
          .sevk-row-table { border-collapse: separate !important; }
          img { border: 0; height: auto; line-height: 100%; outline: none; text-decoration: none; -ms-interpolation-mode: bicubic; }
          @media only screen and (max-width: 479px) {
            .sevk-row-table { width: 100% !important; }
            .sevk-column { display: block !important; width: 100% !important; max-width: 100% !important; }
          }
          </style>
          #{title}
          #{font_links}
          #{styles}
          </head>
          <body style="margin:0;padding:0;word-spacing:normal;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;font-family:ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
          <div aria-roledescription="email" role="article">
          #{preview_text}
          #{content}
          </div>
          </body>
          </html>
        HTML
      end
    end

    # Module-level render method
    def self.render(markup)
      Renderer.new.render(markup)
    end
  end
end
