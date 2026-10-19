# frozen_string_literal: true

module Sevk
  module Markup
    module StyleHelpers
      STYLE_ORDER = %w[
        color background-color background-image background-size background-position background-repeat
        font-size font-family font-weight line-height text-align text-decoration
        width height max-width max-height min-width min-height
        padding padding-top padding-right padding-bottom padding-left
        margin margin-top margin-right margin-bottom margin-left
        border border-color border-width border-style
        border-top border-right border-bottom border-left
        border-radius border-top-left-radius border-top-right-radius
        border-bottom-left-radius border-bottom-right-radius
        border-collapse list-style-type vertical-align
      ].freeze

      private

      def parse_attributes(attrs_str)
        attrs = {}
        attrs_str.scan(/([\w-]+)=(?:"([^"]*)"|'([^']*)')/) do |key, dq_val, sq_val|
          attrs[key] = dq_val.nil? || dq_val.empty? ? (sq_val || '') : dq_val
        end
        attrs
      end

      def extract_all_style_attributes(attrs)
        attrs = attrs.reject { |_, value| value.to_s.empty? }
        style = {}

        if attrs['text-color']
          style['color'] = attrs['text-color']
        elsif attrs['color']
          style['color'] = attrs['color']
        end
        style['background-color'] = attrs['background-color'] if attrs['background-color']
        # Background image group lives between background-color and font-size to
        # match the reference extractStyleAttributes insertion order.
        bg_image = attrs['background-image']
        style['background-image'] = "url('#{bg_image}')" if bg_image
        if attrs['background-size']
          style['background-size'] = attrs['background-size']
        elsif bg_image
          style['background-size'] = 'cover'
        end
        if attrs['background-position']
          style['background-position'] = attrs['background-position']
        elsif bg_image
          style['background-position'] = 'center'
        end
        if attrs['background-repeat']
          style['background-repeat'] = attrs['background-repeat']
        elsif bg_image
          style['background-repeat'] = 'no-repeat'
        end
        style['font-size'] = attrs['font-size'] if attrs['font-size']
        style['font-family'] = attrs['font-family'] if attrs['font-family']
        style['font-weight'] = attrs['font-weight'] if attrs['font-weight']
        style['line-height'] = attrs['line-height'] if attrs['line-height']
        style['text-align'] = attrs['text-align'] if attrs['text-align']
        style['text-decoration'] = attrs['text-decoration'] if attrs['text-decoration']

        style['width'] = attrs['width'] if attrs['width']
        style['height'] = attrs['height'] if attrs['height']
        style['max-width'] = attrs['max-width'] if attrs['max-width']
        style['max-height'] = attrs['max-height'] if attrs['max-height']
        style['min-width'] = attrs['min-width'] if attrs['min-width']
        style['min-height'] = attrs['min-height'] if attrs['min-height']

        # Spacing - Padding (shorthand + per-side both emit; per-side wins per CSS)
        style['padding'] = attrs['padding'] if attrs['padding']
        style['padding-top'] = attrs['padding-top'] if attrs['padding-top']
        style['padding-right'] = attrs['padding-right'] if attrs['padding-right']
        style['padding-bottom'] = attrs['padding-bottom'] if attrs['padding-bottom']
        style['padding-left'] = attrs['padding-left'] if attrs['padding-left']

        # Spacing - Margin (shorthand + per-side both emit; per-side wins per CSS)
        style['margin'] = attrs['margin'] if attrs['margin']
        style['margin-top'] = attrs['margin-top'] if attrs['margin-top']
        style['margin-right'] = attrs['margin-right'] if attrs['margin-right']
        style['margin-bottom'] = attrs['margin-bottom'] if attrs['margin-bottom']
        style['margin-left'] = attrs['margin-left'] if attrs['margin-left']

        # Borders cascade: shorthand -> per-property -> per-side (most specific last)
        style['border'] = attrs['border'] if attrs['border']
        style['border-color'] = attrs['border-color'] if attrs['border-color']
        style['border-width'] = attrs['border-width'] if attrs['border-width']
        style['border-style'] = attrs['border-style'] if attrs['border-style']
        style['border-top'] = attrs['border-top'] if attrs['border-top']
        style['border-right'] = attrs['border-right'] if attrs['border-right']
        style['border-bottom'] = attrs['border-bottom'] if attrs['border-bottom']
        style['border-left'] = attrs['border-left'] if attrs['border-left']

        # Border Radius (shorthand + per-corner both emit; per-corner wins per CSS)
        style['border-radius'] = attrs['border-radius'] if attrs['border-radius']
        style['border-top-left-radius'] = attrs['border-top-left-radius'] if attrs['border-top-left-radius']
        style['border-top-right-radius'] = attrs['border-top-right-radius'] if attrs['border-top-right-radius']
        style['border-bottom-left-radius'] = attrs['border-bottom-left-radius'] if attrs['border-bottom-left-radius']
        style['border-bottom-right-radius'] = attrs['border-bottom-right-radius'] if attrs['border-bottom-right-radius']

        style
      end

      def class_attribute(attrs)
        value = attrs['class'].to_s.empty? ? attrs['className'] : attrs['class']
        value.to_s.empty? ? '' : %( class="#{value}")
      end

      def style_to_string(style)
        seen = {}
        parts = []
        STYLE_ORDER.each do |key|
          value = style[key]
          next if value.nil? || value == ''

          parts << "#{key}:#{value}"
          seen[key] = true
        end
        style.each do |key, value|
          next if seen[key]
          next if value.nil? || value == ''

          parts << "#{key}:#{value}"
        end
        parts.join(';')
      end
    end
  end
end
