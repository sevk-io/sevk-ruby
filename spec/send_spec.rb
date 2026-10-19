# frozen_string_literal: true

require 'sevk'

RSpec.describe 'Send' do
  it 'sends a markup email through the Sevk API' do
    api_key = ENV.fetch('SEVK_API_KEY', nil)
    from = ENV.fetch('SEVK_TEST_FROM', nil)
    to = ENV.fetch('SEVK_TEST_TO', nil)
    if [api_key, from, to].any? { |value| value.nil? || value.empty? }
      skip 'SEVK_API_KEY, SEVK_TEST_FROM and SEVK_TEST_TO are required'
    end

    client = Sevk::Client.new(api_key: api_key, base_url: ENV.fetch('SEVK_BASE_URL', nil))
    response = client.emails.send(from: from, to: to, subject: 'Sevk SDK send test',
                                  markup: '<section><paragraph>Hello from the Sevk Ruby SDK</paragraph></section>')

    expect(response.fetch('id')).to be_a(String)
    expect(response.fetch('id')).not_to be_empty
  end
end
