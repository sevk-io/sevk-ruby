# frozen_string_literal: true

module Sevk
  module Markup
    module HtmlDocument
      private

      def generate_html(content)
        lang = @head_settings.lang.empty? ? 'en' : @head_settings.lang
        dir = @head_settings.dir.empty? ? 'ltr' : @head_settings.dir

        title = @head_settings.title.empty? ? '' : "<title>#{@head_settings.title}</title>"

        font_links = @head_settings.fonts.map do |font|
          %(<link href="#{font.url}" rel="stylesheet" type="text/css" />)
        end.join("\n")

        styles = @head_settings.styles.empty? ? '' : %(<style type="text/css">#{@head_settings.styles}</style>)

        gap_rules = @gap_rules || []
        gap_style_tag =
          if gap_rules.empty?
            ''
          else
            %(<style type="text/css">@media only screen and (max-width:479px){#{gap_rules.join}}</style>)
          end

        preview_text = ''
        unless @head_settings.preview_text.empty?
          preview_style =
            'display:none;font-size:1px;color:#ffffff;line-height:1px;' \
            'max-height:0px;max-width:0px;opacity:0;overflow:hidden;'
          preview_text = %(<div style="#{preview_style}">#{@head_settings.preview_text}</div>)
        end

        <<~HTML.chomp
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
            .sevk-column { display: block !important; width: 100% !important; max-width: 100% !important; box-sizing: border-box !important; }
          }
          </style>
          #{gap_style_tag}
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
  end
end
