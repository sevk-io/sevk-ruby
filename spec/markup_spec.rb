# frozen_string_literal: true

require "spec_helper"

# ============================================
# BLOCK / TEMPLATE ENGINE TESTS
# ============================================
RSpec.describe "Block Template Engine" do
  # ============================================
  # VARIABLE SUBSTITUTION
  # ============================================
  describe "variable substitution" do
    it "should replace a simple variable" do
      markup = '<block config=\'{"name":"Alice"}\'>{%name%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Alice")
      expect(html).not_to include("{%name%}")
    end

    it "should replace multiple variables" do
      markup = '<block config=\'{"first":"John","last":"Doe"}\'>{%first%} {%last%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("John")
      expect(html).to include("Doe")
    end

    it "should use fallback value when variable is missing" do
      markup = '<block config=\'{}\'>{%name ?? Guest%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Guest")
    end

    it "should use fallback value when variable is empty string" do
      markup = '<block config=\'{"name":""}\'>{%name ?? Guest%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Guest")
    end

    it "should not use fallback when variable has a value" do
      markup = '<block config=\'{"name":"Alice"}\'>{%name ?? Guest%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Alice")
      expect(html).not_to include("Guest")
    end

    it "should preserve {{variable}} mustache syntax" do
      markup = '<block config=\'{"name":"Alice"}\'>Hello {%name%}, your code is {{code}}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Alice")
      expect(html).to include("{{code}}")
    end

    it "should preserve {{unsubscribeUrl}} in block output" do
      markup = '<block config=\'{"name":"Alice"}\'>Hello {%name%}, click {{unsubscribeUrl}} to unsubscribe</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Alice")
      expect(html).to include("{{unsubscribeUrl}}")
    end
  end

  # ============================================
  # EACH LOOPS
  # ============================================
  describe "each loop" do
    it "should iterate over an array of objects" do
      markup = '<block config=\'{"items":[{"title":"A"},{"title":"B"},{"title":"C"}]}\'>{%#each items as item%}{%item.title%}{%/each%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("A")
      expect(html).to include("B")
      expect(html).to include("C")
    end

    it "should iterate over an array of strings" do
      markup = '<block config=\'{"tags":["red","green","blue"]}\'>{%#each tags as tag%}{%tag%} {%/each%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("red")
      expect(html).to include("green")
      expect(html).to include("blue")
    end

    it "should render nothing for an empty array" do
      markup = '<block config=\'{"items":[]}\'>{%#each items as item%}{%item.title%}{%/each%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).not_to include("{%")
    end

    it "should render nothing for a missing array variable" do
      markup = '<block config=\'{}\'>{%#each items as item%}{%item.title%}{%/each%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).not_to include("{%")
    end

    it "should support fallback values inside each loop" do
      markup = '<block config=\'{"items":[{"name":"X"},{"name":""}]}\'>{%#each items as item%}[{%item.name ?? unknown%}]{%/each%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("[X]")
      expect(html).to include("[unknown]")
    end
  end

  # ============================================
  # IF/ELSE CONDITIONALS
  # ============================================
  describe "if/else conditionals" do
    it "should render if block when condition is truthy" do
      markup = '<block config=\'{"show":true}\'>{%#if show%}Visible{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Visible")
    end

    it "should not render if block when condition is falsy" do
      markup = '<block config=\'{"show":false}\'>{%#if show%}Visible{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).not_to include("Visible")
    end

    it "should render else block when condition is falsy" do
      markup = '<block config=\'{"show":false}\'>{%#if show%}Yes{%else%}No{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("No")
      expect(html).not_to include("Yes")
    end

    it "should render if block and not else when condition is truthy" do
      markup = '<block config=\'{"show":true}\'>{%#if show%}Yes{%else%}No{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Yes")
      expect(html).not_to include("No")
    end

    it "should not render if block when variable is missing" do
      markup = '<block config=\'{}\'>{%#if missing%}Visible{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).not_to include("Visible")
    end

    it "should handle nested if blocks" do
      markup = '<block config=\'{"a":true,"b":true}\'>{%#if a%}A{%#if b%}B{%/if%}{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("A")
      expect(html).to include("B")
    end

    it "should handle nested if with outer true inner false" do
      markup = '<block config=\'{"a":true,"b":false}\'>{%#if a%}ALPHA{%#if b%}BRAVO{%/if%}{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("ALPHA")
      expect(html).not_to include("BRAVO")
    end

    it "should handle nested if with outer false" do
      markup = '<block config=\'{"a":false,"b":true}\'>{%#if a%}ALPHA{%#if b%}BRAVO{%/if%}{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).not_to include("ALPHA")
      expect(html).not_to include("BRAVO")
    end

    # ---- Truthiness tests ----

    it "should treat empty string as falsy" do
      markup = '<block config=\'{"val":""}\'>{%#if val%}Visible{%else%}Hidden{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Hidden")
      expect(html).not_to include("Visible")
    end

    it "should treat zero as falsy" do
      markup = '<block config=\'{"val":0}\'>{%#if val%}Visible{%else%}Hidden{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Hidden")
      expect(html).not_to include("Visible")
    end

    it "should treat false as falsy" do
      markup = '<block config=\'{"val":false}\'>{%#if val%}Visible{%else%}Hidden{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Hidden")
      expect(html).not_to include("Visible")
    end

    it "should treat empty array as falsy" do
      markup = '<block config=\'{"val":[]}\'>{%#if val%}Visible{%else%}Hidden{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Hidden")
      expect(html).not_to include("Visible")
    end

    it "should treat non-empty string as truthy" do
      markup = '<block config=\'{"val":"hello"}\'>{%#if val%}Visible{%else%}Hidden{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Visible")
      expect(html).not_to include("Hidden")
    end

    it "should treat non-empty array as truthy" do
      markup = '<block config=\'{"val":["a"]}\'>{%#if val%}Visible{%else%}Hidden{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Visible")
      expect(html).not_to include("Hidden")
    end

    it "should treat positive number as truthy" do
      markup = '<block config=\'{"val":42}\'>{%#if val%}Visible{%else%}Hidden{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Visible")
      expect(html).not_to include("Hidden")
    end

    # ---- Combined if + each ----

    it "should render combined if and each together" do
      markup = '<block config=\'{"show":true,"items":[{"name":"ALPHA"},{"name":"BRAVO"}]}\'>{%#if show%}{%#each items as item%}{%item.name%} {%/each%}{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("ALPHA")
      expect(html).to include("BRAVO")
    end

    it "should skip each when wrapping if is false" do
      markup = '<block config=\'{"show":false,"items":[{"name":"ALPHA"},{"name":"BRAVO"}]}\'>{%#if show%}{%#each items as item%}{%item.name%} {%/each%}{%/if%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).not_to include("ALPHA")
      expect(html).not_to include("BRAVO")
    end
  end

  # ============================================
  # BLOCK WITH MARKUP ELEMENTS
  # ============================================
  describe "block with markup elements" do
    it "should render a paragraph inside a block" do
      markup = '<block config=\'{"text":"Hello World"}\'><paragraph>{%text%}</paragraph></block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("<p")
      expect(html).to include("Hello World")
    end

    it "should render a heading inside a block" do
      markup = '<block config=\'{"title":"Welcome"}\'><heading level="2">{%title%}</heading></block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("<h2")
      expect(html).to include("Welcome")
      expect(html).to include("</h2>")
    end

    it "should render a button inside a block" do
      markup = '<block config=\'{"url":"https://example.com","label":"Click"}\'><button href="{%url%}">{%label%}</button></block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("<a")
      expect(html).to include("https://example.com")
      expect(html).to include("Click")
    end

    it "should render an image inside a block" do
      markup = '<block config=\'{"src":"https://example.com/img.png"}\'><image src="{%src%}" alt="photo" /></block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("<img")
      expect(html).to include("https://example.com/img.png")
      expect(html).to include('alt="photo"')
    end

    it "should render a section inside a block" do
      markup = '<block config=\'{"text":"Content"}\'><section>{%text%}</section></block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("<table")
      expect(html).to include("Content")
    end

    it "should render a link inside a block" do
      markup = '<block config=\'{"url":"https://example.com","label":"Visit"}\'><link href="{%url%}">{%label%}</link></block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("<a")
      expect(html).to include("https://example.com")
      expect(html).to include("Visit")
    end
  end

  # ============================================
  # MULTIPLE BLOCKS
  # ============================================
  describe "multiple blocks" do
    it "should render multiple blocks independently" do
      markup = '<block config=\'{"name":"Alice"}\'>Hello {%name%}</block><block config=\'{"name":"Bob"}\'>Hi {%name%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("Hello Alice")
      expect(html).to include("Hi Bob")
    end

    it "should render blocks with different configs" do
      markup = '<block config=\'{"color":"red"}\'>{%color%}</block><block config=\'{"size":"large"}\'>{%size%}</block>'
      html = Sevk::Markup.render(markup)
      expect(html).to include("red")
      expect(html).to include("large")
    end
  end

  # ============================================
  # SOCIAL LINKS TEMPLATE
  # ============================================
  describe "social links template" do
    it "should render social links from an array" do
      config = '{"links":[{"url":"https://twitter.com","icon":"https://example.com/twitter.png"},{"url":"https://github.com","icon":"https://example.com/github.png"}]}'
      markup = "<block config='#{config}'>{%#each links as link%}<link href=\"{%link.url%}\"><image src=\"{%link.icon%}\" alt=\"social\" /></link>{%/each%}</block>"
      html = Sevk::Markup.render(markup)
      expect(html).to include("https://twitter.com")
      expect(html).to include("https://github.com")
      expect(html).to include("https://example.com/twitter.png")
      expect(html).to include("https://example.com/github.png")
    end
  end

  # ============================================
  # HEADER TEMPLATE
  # ============================================
  describe "header template" do
    it "should render a header with logo and title" do
      config = '{"logoUrl":"https://example.com/logo.png","title":"Newsletter","subtitle":"Weekly Update"}'
      markup = "<block config='#{config}'><section><image src=\"{%logoUrl%}\" alt=\"logo\" /><heading level=\"1\">{%title%}</heading><paragraph>{%subtitle%}</paragraph></section></block>"
      html = Sevk::Markup.render(markup)
      expect(html).to include("https://example.com/logo.png")
      expect(html).to include("Newsletter")
      expect(html).to include("Weekly Update")
      expect(html).to include("<h1")
      expect(html).to include("<p")
      expect(html).to include("<img")
    end

    it "should render header with conditional subtitle" do
      config_with = '{"title":"News","hasSubtitle":true,"subtitle":"Latest"}'
      markup = "<block config='#{config_with}'><heading level=\"1\">{%title%}</heading>{%#if hasSubtitle%}<paragraph>{%subtitle%}</paragraph>{%/if%}</block>"
      html = Sevk::Markup.render(markup)
      expect(html).to include("News")
      expect(html).to include("Latest")

      config_without = '{"title":"News","hasSubtitle":false,"subtitle":"Latest"}'
      markup2 = "<block config='#{config_without}'><heading level=\"1\">{%title%}</heading>{%#if hasSubtitle%}<paragraph>{%subtitle%}</paragraph>{%/if%}</block>"
      html2 = Sevk::Markup.render(markup2)
      expect(html2).to include("News")
      expect(html2).not_to include("Latest")
    end
  end
end

# ============================================
# LANG AND DIR SUPPORT TESTS
# ============================================
RSpec.describe "Lang and Dir Support" do
  it "should default to lang='en' and dir='ltr' when not specified" do
    html = Sevk::Markup.render("<mail><body><paragraph>Hello</paragraph></body></mail>")
    expect(html).to include('lang="en"')
    expect(html).to include('dir="ltr"')
  end

  it "should use lang attribute from mail tag" do
    html = Sevk::Markup.render('<mail lang="fr"><body><paragraph>Bonjour</paragraph></body></mail>')
    expect(html).to include('lang="fr"')
    expect(html).to include('dir="ltr"')
  end

  it "should use dir attribute from mail tag" do
    html = Sevk::Markup.render('<mail dir="rtl"><body><paragraph>Hello</paragraph></body></mail>')
    expect(html).to include('lang="en"')
    expect(html).to include('dir="rtl"')
  end

  it "should use both lang and dir attributes from mail tag" do
    html = Sevk::Markup.render('<mail lang="ar" dir="rtl"><body><paragraph>مرحبا</paragraph></body></mail>')
    expect(html).to include('lang="ar"')
    expect(html).to include('dir="rtl"')
  end

  it "should use lang and dir from email tag" do
    html = Sevk::Markup.render('<email lang="de" dir="ltr"><body><paragraph>Hallo</paragraph></body></email>')
    expect(html).to include('lang="de"')
    expect(html).to include('dir="ltr"')
  end
end

# ============================================
# DOCUMENT STRUCTURE TESTS
# ============================================
RSpec.describe "Markup Document Structure" do
  it "should render a paragraph element" do
    html = Sevk::Markup.render("<paragraph>Hello World</paragraph>")
    expect(html).to include("<p")
    expect(html).to include("Hello World")
    expect(html).to include("</p>")
  end

  it "should render a paragraph with style attributes" do
    html = Sevk::Markup.render('<paragraph color="#333" font-size="16px">Styled text</paragraph>')
    expect(html).to include("color:#333")
    expect(html).to include("font-size:16px")
    expect(html).to include("Styled text")
  end

  it "should render heading with level" do
    html = Sevk::Markup.render('<heading level="1">Title</heading>')
    expect(html).to include("<h1")
    expect(html).to include("Title")
    expect(html).to include("</h1>")
  end

  it "should render heading level 2" do
    html = Sevk::Markup.render('<heading level="2">Subtitle</heading>')
    expect(html).to include("<h2")
    expect(html).to include("Subtitle")
    expect(html).to include("</h2>")
  end

  it "should render heading level 3" do
    html = Sevk::Markup.render('<heading level="3">Section</heading>')
    expect(html).to include("<h3")
    expect(html).to include("Section")
    expect(html).to include("</h3>")
  end

  it "should default heading to level 1" do
    html = Sevk::Markup.render("<heading>Default</heading>")
    expect(html).to include("<h1")
    expect(html).to include("Default")
  end

  it "should render a button as a link" do
    html = Sevk::Markup.render('<button href="https://example.com">Click Me</button>')
    expect(html).to include("<a")
    expect(html).to include("https://example.com")
    expect(html).to include("Click Me")
    expect(html).to include('target="_blank"')
  end

  it "should render a button with style attributes" do
    html = Sevk::Markup.render('<button href="#" background-color="#007bff" color="#fff" padding="12px 24px">Submit</button>')
    expect(html).to include("background-color:#007bff")
    expect(html).to include("color:#fff")
    expect(html).to include("Submit")
  end

  it "should render an image tag" do
    html = Sevk::Markup.render('<image src="https://example.com/photo.jpg" alt="A photo" width="200" />')
    expect(html).to include("<img")
    expect(html).to include('src="https://example.com/photo.jpg"')
    expect(html).to include('alt="A photo"')
    expect(html).to include('width="200"')
  end

  it "should render image with default styles" do
    html = Sevk::Markup.render('<image src="test.jpg" />')
    expect(html).to include("max-width:100%")
    expect(html).to include("outline:none")
    expect(html).to include("border:none")
    expect(html).to include("text-decoration:none")
  end

  it "should render a section as a table" do
    html = Sevk::Markup.render("<section><paragraph>Content</paragraph></section>")
    expect(html).to include("<table")
    expect(html).to include('role="presentation"')
    expect(html).to include("<td>")
    expect(html).to include("Content")
  end

  it "should render a section with style attributes" do
    html = Sevk::Markup.render('<section background-color="#f0f0f0" padding="20px">Inner</section>')
    expect(html).to include("background-color:#f0f0f0")
    expect(html).to include("padding:20px")
  end

  it "should render a container as a table" do
    html = Sevk::Markup.render("<container><paragraph>Inside</paragraph></container>")
    expect(html).to include("<table")
    expect(html).to include('role="presentation"')
    expect(html).to include("Inside")
  end

  it "should render container with max-width from width" do
    html = Sevk::Markup.render('<container width="600px"><paragraph>Content</paragraph></container>')
    expect(html).to include("max-width:600px")
    expect(html).to include("width:100%")
  end

  it "should render a row and column layout" do
    html = Sevk::Markup.render("<row><column>Left</column><column>Right</column></row>")
    expect(html).to include("sevk-row-table")
    expect(html).to include("sevk-column")
    expect(html).to include("Left")
    expect(html).to include("Right")
  end

  it "should assign equal widths to columns" do
    html = Sevk::Markup.render("<row><column>A</column><column>B</column></row>")
    expect(html).to include("width:50%")
  end

  it "should render three equal columns" do
    html = Sevk::Markup.render("<row><column>A</column><column>B</column><column>C</column></row>")
    expect(html).to include("width:33%")
  end

  it "should render a row with gap" do
    html = Sevk::Markup.render('<row gap="16px"><column>A</column><column>B</column></row>')
    expect(html).to include("margin-bottom:16px")
  end

  it "should render an unordered list" do
    html = Sevk::Markup.render("<list><li>Item 1</li><li>Item 2</li></list>")
    expect(html).to include("<ul")
    expect(html).to include("<li")
    expect(html).to include("Item 1")
    expect(html).to include("Item 2")
  end

  it "should render an ordered list" do
    html = Sevk::Markup.render('<list type="ordered"><li>First</li><li>Second</li></list>')
    expect(html).to include("<ol")
    expect(html).to include("First")
    expect(html).to include("Second")
  end

  it "should render a divider" do
    html = Sevk::Markup.render("<divider />")
    expect(html).to include("<hr")
  end

  it "should render a link element" do
    html = Sevk::Markup.render('<link href="https://example.com">Click here</link>')
    expect(html).to include("<a")
    expect(html).to include("https://example.com")
    expect(html).to include("Click here")
    expect(html).to include('target="_blank"')
  end

  it "should render nested elements" do
    markup = '<section><container width="600px"><row><column><heading level="1">Title</heading><paragraph>Body text</paragraph><button href="#">Action</button></column></row></container></section>'
    html = Sevk::Markup.render(markup)
    expect(html).to include("<h1")
    expect(html).to include("Title")
    expect(html).to include("<p")
    expect(html).to include("Body text")
    expect(html).to include("<a")
    expect(html).to include("Action")
  end
end
