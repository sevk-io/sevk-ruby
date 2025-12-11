# frozen_string_literal: true

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
      attr_accessor :title, :preview_text, :styles, :fonts

      def initialize
        @title = ""
        @preview_text = ""
        @styles = ""
        @fonts = []
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

        # Normalize markup
        markup = normalize_markup(markup)

        # Process markup using regex
        processed = process_markup(markup)

        generate_html(processed)
      end

      private

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

        # Process row tags
        result = process_tag(result, "row") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          %(<table align="center" width="100%" border="0" cellPadding="0" cellSpacing="0" role="presentation" style="#{style_str}">
<tbody style="width:100%">
<tr style="width:100%">#{inner}</tr>
</tbody>
</table>)
        end

        # Process column tags
        result = process_tag(result, "column") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          %(<td style="#{style_str}">#{inner}</td>)
        end

        # Process container tags
        result = process_tag(result, "container") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          %(<table align="center" width="100%" border="0" cellPadding="0" cellSpacing="0" role="presentation" style="#{style_str}">
<tbody>
<tr style="width:100%">
<td>#{inner}</td>
</tr>
</tbody>
</table>)
        end

        # Process heading tags
        result = process_tag(result, "heading") do |attrs, inner|
          level = attrs["level"] || "1"
          style = extract_all_style_attributes(attrs)
          style_str = style_to_string(style)
          %(<h#{level} style="#{style_str}">#{inner}</h#{level}>)
        end

        # Process paragraph tags
        result = process_tag(result, "paragraph") do |attrs, inner|
          style = extract_all_style_attributes(attrs)
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
          style["outline"] ||= "none"
          style["border"] ||= "none"
          style["text-decoration"] ||= "none"

          style_str = style_to_string(style)
          width_attr = width ? %( width="#{width}") : ""
          height_attr = height ? %( height="#{height}") : ""

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
          style = extract_all_style_attributes(attrs)
          style["width"] ||= "100%"
          style["box-sizing"] ||= "border-box"
          style_str = style_to_string(style)
          escaped = inner.gsub("<", "&lt;").gsub(">", "&gt;")
          %(<pre style="#{style_str}"><code>#{escaped}</code></pre>)
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

            # Find the next close tag after this opening tag
            close_pos = result.downcase.index(close_tag.downcase, inner_start)
            next unless close_pos

            inner = result[inner_start...close_pos]

            # Check if there's another opening tag inside
            next if inner.downcase.include?(open_tag_start.downcase)

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
        attrs_str.scan(/([\w-]+)=["']([^"']*)["']/) do |key, value|
          attrs[key] = value
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

        style
      end

      def style_to_string(style)
        style.map { |k, v| "#{k}:#{v}" }.join(";")
      end

      def generate_html(content)
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
          <html lang="en" dir="ltr">
          <head>
          <meta content="text/html; charset=UTF-8" http-equiv="Content-Type"/>
          <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
          #{title}
          #{font_links}
          #{styles}
          </head>
          <body style="margin:0;padding:0;font-family:ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;background-color:#ffffff">
          #{preview_text}
          #{content}
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
