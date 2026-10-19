# frozen_string_literal: true

module Sevk
  module Markup
    module SyntaxHighlighting
      MAX_CODEBLOCK_LENGTH = 2500
      MAX_TOTAL_CODEBLOCK_LENGTH = 2500

      LANGUAGES = %w[
        plain extend plaintext text txt markup html mathml svg xml ssml atom rss css clike javascript js typescript ts
        jsx tsx python py java c cpp csharp cs dotnet php ruby rb go rust sql bash sh shell json webmanifest
        yaml yml markdown md
      ].freeze

      LANGUAGE_ALIASES = { 'jsx' => 'javascript', 'tsx' => 'typescript' }.freeze

      ROUGE_LEXERS = {
        'markup' => 'html', 'mathml' => 'xml', 'svg' => 'xml', 'ssml' => 'xml', 'atom' => 'xml', 'rss' => 'xml',
        'dotnet' => 'csharp', 'webmanifest' => 'json', 'plain' => nil, 'plaintext' => nil, 'text' => nil,
        'txt' => nil, 'clike' => nil
      }.freeze

      THEME_BASES = {
        'vscDarkPlus' => {
          'color' => '#d4d4d4', 'fontSize' => '13px', 'textShadow' => 'none',
          'fontFamily' => "Menlo, Monaco, Consolas, 'Andale Mono', 'Ubuntu Mono', 'Courier New', monospace",
          'direction' => 'ltr', 'textAlign' => 'left', 'whiteSpace' => 'pre', 'wordSpacing' => 'normal',
          'wordBreak' => 'normal', 'lineHeight' => '1.5', 'MozTabSize' => '4', 'OTabSize' => '4', 'tabSize' => '4',
          'WebkitHyphens' => 'none', 'MozHyphens' => 'none', 'hyphens' => 'none', 'padding' => '16px',
          'overflow' => 'auto', 'backgroundColor' => '#1e1e1e'
        },
        'vs' => {
          'color' => '#393A34',
          'fontFamily' => "'Consolas', 'Bitstream Vera Sans Mono', 'Courier New', Courier, monospace",
          'direction' => 'ltr', 'textAlign' => 'left', 'whiteSpace' => 'pre', 'wordSpacing' => 'normal',
          'wordBreak' => 'normal', 'fontSize' => '.9em', 'lineHeight' => '1.2em', 'MozTabSize' => '4',
          'OTabSize' => '4', 'tabSize' => '4', 'WebkitHyphens' => 'none', 'MozHyphens' => 'none',
          'hyphens' => 'none', 'padding' => '16px', 'overflow' => 'auto', 'border' => '1px solid #dddddd',
          'backgroundColor' => 'white'
        },
        'oneDark' => {
          'backgroundColor' => '#282c34', 'color' => '#abb2bf', 'textShadow' => '0 1px rgba(0, 0, 0, 0.3)',
          'fontFamily' => "'Fira Code', 'Fira Mono', Menlo, Consolas, 'DejaVu Sans Mono', monospace",
          'direction' => 'ltr', 'textAlign' => 'left', 'whiteSpace' => 'pre', 'wordSpacing' => 'normal',
          'wordBreak' => 'normal', 'lineHeight' => '1.5', 'MozTabSize' => '2', 'OTabSize' => '2', 'tabSize' => '2',
          'WebkitHyphens' => 'none', 'MozHyphens' => 'none', 'hyphens' => 'none', 'padding' => '16px',
          'overflow' => 'auto', 'borderRadius' => '6px'
        },
        'oneLight' => {
          'backgroundColor' => '#fafafa', 'color' => '#383a42',
          'fontFamily' => "'Fira Code', 'Fira Mono', Menlo, Consolas, 'DejaVu Sans Mono', monospace",
          'direction' => 'ltr', 'textAlign' => 'left', 'whiteSpace' => 'pre', 'wordSpacing' => 'normal',
          'wordBreak' => 'normal', 'lineHeight' => '1.5', 'MozTabSize' => '2', 'OTabSize' => '2', 'tabSize' => '2',
          'WebkitHyphens' => 'none', 'MozHyphens' => 'none', 'hyphens' => 'none', 'padding' => '16px',
          'overflow' => 'auto', 'borderRadius' => '6px'
        }
      }.freeze

      THEME_TOKENS = {
        'vscDarkPlus' => {
          'comment' => { 'color' => '#6a9955' }, 'prolog' => { 'color' => '#6a9955' },
          'punctuation' => { 'color' => '#d4d4d4' }, 'property' => { 'color' => '#9cdcfe' },
          'tag' => { 'color' => '#569cd6' }, 'boolean' => { 'color' => '#569cd6' },
          'number' => { 'color' => '#b5cea8' }, 'constant' => { 'color' => '#9cdcfe' },
          'symbol' => { 'color' => '#b5cea8' }, 'inserted' => { 'color' => '#b5cea8' },
          'selector' => { 'color' => '#d7ba7d' }, 'attr-name' => { 'color' => '#9cdcfe' },
          'string' => { 'color' => '#ce9178' }, 'char' => { 'color' => '#ce9178' },
          'builtin' => { 'color' => '#ce9178' }, 'deleted' => { 'color' => '#ce9178' },
          'operator' => { 'color' => '#d4d4d4' }, 'entity' => { 'color' => '#569cd6' },
          'atrule' => { 'color' => '#ce9178' }, 'keyword' => { 'color' => '#569CD6' },
          'function' => { 'color' => '#dcdcaa' }, 'regex' => { 'color' => '#d16969' },
          'important' => { 'color' => '#569cd6' }, 'italic' => { 'font-style' => 'italic' },
          'class-name' => { 'color' => '#4ec9b0' }, 'variable' => { 'color' => '#9cdcfe' },
          'attr-value' => { 'color' => '#ce9178' }, 'cdata' => { 'color' => '#808080' },
          'namespace' => { 'color' => '#4ec9b0' }
        },
        'vs' => {
          'comment' => { 'color' => '#008000', 'font-style' => 'italic' },
          'prolog' => { 'color' => '#008000', 'font-style' => 'italic' },
          'doctype' => { 'color' => '#008000', 'font-style' => 'italic' },
          'cdata' => { 'color' => '#008000', 'font-style' => 'italic' }, 'namespace' => { 'opacity' => '.7' },
          'string' => { 'color' => '#A31515' }, 'punctuation' => { 'color' => '#393A34' },
          'operator' => { 'color' => '#393A34' }, 'url' => { 'color' => '#36acaa' },
          'symbol' => { 'color' => '#36acaa' }, 'number' => { 'color' => '#36acaa' },
          'boolean' => { 'color' => '#36acaa' }, 'variable' => { 'color' => '#36acaa' },
          'constant' => { 'color' => '#36acaa' }, 'inserted' => { 'color' => '#36acaa' },
          'atrule' => { 'color' => '#0000ff' }, 'keyword' => { 'color' => '#0000ff' },
          'attr-value' => { 'color' => '#0000ff' }, 'function' => { 'color' => '#393A34' },
          'deleted' => { 'color' => '#9a050f' }, 'selector' => { 'color' => '#800000' },
          'important' => { 'color' => '#e90', 'font-weight' => 'bold' }, 'bold' => { 'font-weight' => 'bold' },
          'italic' => { 'font-style' => 'italic' }, 'class-name' => { 'color' => '#2B91AF' },
          'tag' => { 'color' => '#800000' }, 'attr-name' => { 'color' => '#ff0000' },
          'property' => { 'color' => '#ff0000' }, 'regex' => { 'color' => '#ff0000' },
          'entity' => { 'color' => '#ff0000' }
        },
        'oneDark' => {
          'comment' => { 'color' => '#5c6370', 'font-style' => 'italic' }, 'prolog' => { 'color' => '#5c6370' },
          'cdata' => { 'color' => '#5c6370' }, 'doctype' => { 'color' => '#abb2bf' },
          'punctuation' => { 'color' => '#abb2bf' }, 'entity' => { 'color' => '#abb2bf', 'cursor' => 'help' },
          'attr-name' => { 'color' => '#d19a66' }, 'class-name' => { 'color' => '#d19a66' },
          'boolean' => { 'color' => '#d19a66' }, 'constant' => { 'color' => '#d19a66' },
          'number' => { 'color' => '#d19a66' }, 'atrule' => { 'color' => '#d19a66' },
          'keyword' => { 'color' => '#c678dd' }, 'property' => { 'color' => '#e06c75' },
          'tag' => { 'color' => '#e06c75' }, 'symbol' => { 'color' => '#e06c75' },
          'deleted' => { 'color' => '#e06c75' }, 'important' => { 'color' => '#e06c75' },
          'selector' => { 'color' => '#98c379' }, 'string' => { 'color' => '#98c379' },
          'char' => { 'color' => '#98c379' }, 'builtin' => { 'color' => '#98c379' },
          'inserted' => { 'color' => '#98c379' }, 'regex' => { 'color' => '#98c379' },
          'attr-value' => { 'color' => '#98c379' }, 'variable' => { 'color' => '#61afef' },
          'operator' => { 'color' => '#61afef' }, 'function' => { 'color' => '#61afef' },
          'url' => { 'color' => '#56b6c2' }, 'bold' => { 'font-weight' => 'bold' },
          'italic' => { 'font-style' => 'italic' }, 'namespace' => { 'opacity' => '0.8' }
        },
        'oneLight' => {
          'comment' => { 'color' => '#a0a1a7', 'font-style' => 'italic' }, 'prolog' => { 'color' => '#a0a1a7' },
          'cdata' => { 'color' => '#a0a1a7' }, 'doctype' => { 'color' => '#383a42' },
          'punctuation' => { 'color' => '#383a42' }, 'entity' => { 'color' => '#383a42', 'cursor' => 'help' },
          'attr-name' => { 'color' => '#b76b01' }, 'class-name' => { 'color' => '#b76b01' },
          'boolean' => { 'color' => '#b76b01' }, 'constant' => { 'color' => '#b76b01' },
          'number' => { 'color' => '#b76b01' }, 'atrule' => { 'color' => '#b76b01' },
          'keyword' => { 'color' => '#a626a4' }, 'property' => { 'color' => '#e45649' },
          'tag' => { 'color' => '#e45649' }, 'symbol' => { 'color' => '#e45649' },
          'deleted' => { 'color' => '#e45649' }, 'important' => { 'color' => '#e45649' },
          'selector' => { 'color' => '#50a14f' }, 'string' => { 'color' => '#50a14f' },
          'char' => { 'color' => '#50a14f' }, 'builtin' => { 'color' => '#50a14f' },
          'inserted' => { 'color' => '#50a14f' }, 'regex' => { 'color' => '#50a14f' },
          'attr-value' => { 'color' => '#50a14f' }, 'variable' => { 'color' => '#4078f2' },
          'operator' => { 'color' => '#4078f2' }, 'function' => { 'color' => '#4078f2' },
          'url' => { 'color' => '#0184bc' }, 'bold' => { 'font-weight' => 'bold' },
          'italic' => { 'font-style' => 'italic' }, 'namespace' => { 'opacity' => '0.8' }
        }
      }.freeze

      ROUGE_TOKENS = {
        'Comment' => 'comment', 'Keyword' => 'keyword', 'Keyword.Constant' => 'boolean', 'Keyword.Type' => 'class-name',
        'Literal.String' => 'string', 'Literal.String.Regex' => 'regex', 'Literal.String.Symbol' => 'symbol',
        'Literal.String.Escape' => 'string', 'Literal.Number' => 'number', 'Name.Function' => 'function',
        'Name.Class' => 'class-name', 'Name.Constant' => 'constant', 'Name.Builtin' => 'builtin',
        'Name.Variable' => 'variable', 'Name.Tag' => 'tag', 'Name.Attribute' => 'attr-name',
        'Name.Decorator' => 'function', 'Name.Namespace' => 'namespace', 'Name.Entity' => 'entity',
        'Name.Label' => 'symbol', 'Name.Property' => 'property', 'Operator' => 'operator',
        'Operator.Word' => 'keyword', 'Punctuation' => 'punctuation', 'Generic.Deleted' => 'deleted',
        'Generic.Inserted' => 'inserted', 'Generic.Emph' => 'italic', 'Generic.Strong' => 'bold',
        'Generic.Heading' => 'important', 'Generic.Subheading' => 'important'
      }.freeze

      TOKEN_SPACE = "\u00A0\u200D\u200B"

      private

      def process_codeblock(attrs, code)
        requested = (attrs['language'].to_s.empty? ? 'javascript' : attrs['language']).downcase
        language = LANGUAGE_ALIASES.fetch(requested, requested)
        theme = THEME_BASES.key?(attrs['theme'].to_s) ? attrs['theme'] : 'oneDark'
        custom_style = extract_all_style_attributes(attrs)

        return '<pre><code></code></pre>' if code.empty?

        length = code.length + code.count("\u{10000}-\u{10FFFF}")

        if !LANGUAGES.include?(language) || length > MAX_CODEBLOCK_LENGTH ||
           @codeblock_budget + length > MAX_TOTAL_CODEBLOCK_LENGTH
          style = pre_style(THEME_BASES[theme], { 'width' => '100%' }, custom_style)
          escaped = code.gsub('<', '&lt;').gsub('>', '&gt;')
          return %(<pre style="#{style}"><code>#{escaped}</code></pre>)
        end

        @codeblock_budget += length
        inherited = attrs['font-family'].to_s.empty? ? {} : { 'font-family' => attrs['font-family'] }
        lines = highlight_lines(code, language, theme, inherited)
        numbered = attrs['line-numbers'] == 'true'
        html = lines.each_with_index.map do |line, index|
          number = numbered ? %(<span style="width:2em;display:inline-block">#{index + 1}</span>) : ''
          %(<p style="margin:0;min-height:1em">#{number}#{line}</p>)
        end.join
        style = pre_style(THEME_BASES[theme], { 'width' => '100%', 'box-sizing' => 'border-box' }, custom_style)
        %(<pre style="#{style}"><code>#{html}</code></pre>)
      end

      def pre_style(*layers)
        style = {}
        layers.each { |layer| layer.each { |key, value| style[key] = value } }
        style.map do |key, value|
          property = key.gsub(/[A-Z]/) { |letter| "-#{letter.downcase}" }
          property = "-#{property}" if property.start_with?('ms-')
          "#{property}:#{value}"
        end.join(';')
      end

      def highlight_lines(code, language, theme, inherited)
        lexer_name = ROUGE_LEXERS.fetch(language, language)
        lexer = lexer_name && Rouge::Lexer.find(lexer_name)&.new
        tokens = [[nil, code]]
        tokens = lexer.lex(code).map { |type, text| [token_style(theme, type, inherited), text] } if lexer
        inherited_style = style_to_string(inherited)
        lines = [+'']

        tokens.each do |style, text|
          style = inherited_style if style.nil? && !inherited.empty?
          text.split("\n", -1).each_with_index do |part, index|
            lines << +'' if index.positive?
            next if part.empty?

            escaped = part.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
                          .gsub("'", '&#39;').gsub(' ', TOKEN_SPACE)
            lines.last << (style.nil? || style.empty? ? escaped : %(<span style="#{style}">#{escaped}</span>))
          end
        end

        lines
      end

      def token_style(theme, type, inherited)
        qualname = type.qualname
        token = nil
        until token || qualname.nil?
          token = ROUGE_TOKENS[qualname]
          dot = qualname.rindex('.')
          qualname = dot ? qualname[0...dot] : nil
        end
        return nil if token.nil?

        style_to_string(inherited.merge(THEME_TOKENS[theme].fetch(token, {})))
      end
    end
  end
end
