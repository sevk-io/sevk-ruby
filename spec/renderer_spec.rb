# frozen_string_literal: true

require 'sevk'

RSpec.describe 'Renderer' do
  it 'renders markup into an HTML email document' do
    html = Sevk::Markup.render('<section><paragraph>Hello world</paragraph></section>')

    expect(html).to start_with('<!DOCTYPE html PUBLIC')
    expect(html).to include('Hello world')
    expect(html).not_to include('<paragraph>')
  end
end
