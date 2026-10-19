# frozen_string_literal: true

module Sevk
  module Markup
    module DocumentParser
      private

      def extract_body_content(markup)
        unless sevk_document?(markup)
          body = get_first_tag_content(markup, 'body') || markup
          preview = hidden_preview(markup)
          body = body.sub(preview[0], '') if preview
          return body.strip
        end

        body = (get_first_tag_content(markup, 'body') || '').strip
        return body unless body.empty?

        stripped = replace_self_closing(markup, 'email') { '' }
        stripped = replace_self_closing(stripped, 'mail') { '' }.gsub(%r{</(?:email|mail)>}i, '')
        %w[head title preview style].each { |tag| stripped = strip_tag_pairs(stripped, tag) }
        replace_self_closing(stripped, 'font') { '' }.gsub(%r{</font>}i, '').strip
      end

      def sevk_document?(markup)
        markup.match?(/<(?:email|mail)[\s>]/i)
      end

      def hidden_preview(html)
        find_hidden_preview_div(html)
      end

      def parse_head_settings(markup)
        return parse_html_head_settings(markup) unless sevk_document?(markup)

        root_attrs = get_tag_attributes(markup, 'email').first || get_tag_attributes(markup, 'mail').first
        if root_attrs
          if (lang_match = root_attrs.match(/lang=["']([^"']*)["']/i))
            @head_settings.lang = lang_match[1]
          end
          if (dir_match = root_attrs.match(/dir=["']([^"']*)["']/i))
            @head_settings.dir = dir_match[1]
          end
        end

        @head_settings.title = (get_first_tag_content(markup, 'title') || '').strip
        @head_settings.preview_text = (get_first_tag_content(markup, 'preview') || '').strip
        @head_settings.styles = (get_first_tag_content(markup, 'style') || '').strip

        seen_urls = {}
        get_tag_attributes(markup, 'font').each do |attributes|
          name = attributes.match(/name=["']([^"']*)["']/i)
          url = attributes.match(/url=["']([^"']*)["']/i)
          next if name.nil? || url.nil? || seen_urls[url[1]]

          seen_urls[url[1]] = true
          @head_settings.fonts << FontConfig.new(
            id: "font-#{@head_settings.fonts.length}", name: name[1], url: url[1]
          )
        end
      end

      def parse_html_head_settings(html)
        @head_settings.title = (get_first_tag_content(html, 'title') || '').strip
        @head_settings.styles = get_all_tag_contents(html, 'style').join("\n")

        get_tag_attributes(html, 'link').each do |attributes|
          href = attributes.match(/href=["']([^"']*)["']/i)
          next if href.nil? || !href[1].downcase.include?('fonts')

          family = href[1].match(/family=([^:&]+)/)
          index = @head_settings.fonts.length
          @head_settings.fonts << FontConfig.new(
            id: "font-#{index}", name: family ? family[1].tr('+', ' ') : "Font #{index + 1}", url: href[1]
          )
        end

        preview = hidden_preview(html)
        @head_settings.preview_text = preview[1].strip if preview
      end
    end
  end
end
