# frozen_string_literal: true

require "spec_helper"

BASE_URL = "http://localhost:4000"

def unique_id
  "#{Time.now.to_i}#{rand(10000)}"
end

def setup_test_environment
  http = Faraday.new(url: BASE_URL) do |conn|
    conn.request :json
    conn.response :json
    conn.adapter Faraday.default_adapter
  end

  unique = unique_id

  # 1. Register a new test user
  test_email = "sdk-test-#{unique}@test.example.com"
  test_password = "TestPassword123!"

  register_res = http.post("auth/register", {
    email: test_email,
    password: test_password
  })

  raise "Failed to register: #{register_res.status} #{register_res.body}" unless [200, 201].include?(register_res.status)

  token = register_res.body["token"]

  # 2. Create Project
  project_res = http.post("projects") do |req|
    req.headers["Authorization"] = "Bearer #{token}"
    req.body = {
      name: "Test Project",
      slug: "test-project-#{unique}",
      supportEmail: "support@test.com"
    }
  end

  raise "Failed to create project: #{project_res.status} #{project_res.body}" unless [200, 201].include?(project_res.status)

  project_id = project_res.body["project"]["id"]

  # 3. Create API Key
  api_key_res = http.post("projects/#{project_id}/api-keys") do |req|
    req.headers["Authorization"] = "Bearer #{token}"
    req.body = {
      title: "Test Key",
      fullAccess: true
    }
  end

  raise "Failed to create API key: #{api_key_res.status} #{api_key_res.body}" unless [200, 201].include?(api_key_res.status)

  api_key = api_key_res.body["apiKey"]["key"]

  Sevk::Client.new(api_key: api_key, base_url: BASE_URL)
end

# Global test data
$sevk = nil
$shared_audience_id = nil

# Helper to get or create shared audience
def get_shared_audience
  return $shared_audience_id if $shared_audience_id
  audience = $sevk.audiences.create(name: "Shared Test Audience #{unique_id}")
  $shared_audience_id = audience["id"]
  $shared_audience_id
end

RSpec.configure do |config|
  config.before(:suite) do
    $sevk = setup_test_environment
  end
end

# ============================================
# AUTHENTICATION TESTS
# ============================================
RSpec.describe "Authentication" do
  it "should reject invalid API key" do
    invalid_client = Sevk::Client.new(api_key: "sevk_invalid_api_key_12345", base_url: BASE_URL)
    expect { invalid_client.contacts.list }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("401")
      expect(error.message.downcase).to include("invalid")
    end
  end

  it "should reject empty API key" do
    empty_client = Sevk::Client.new(api_key: "", base_url: BASE_URL)
    expect { empty_client.contacts.list }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("401")
    end
  end

  it "should reject malformed API key (not starting with sevk_)" do
    malformed_client = Sevk::Client.new(api_key: "invalid_key_format", base_url: BASE_URL)
    expect { malformed_client.contacts.list }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("401")
    end
  end
end

# ============================================
# CONTACTS TESTS
# ============================================
RSpec.describe "Contacts" do
  it "should list contacts with correct response structure" do
    result = $sevk.contacts.list

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
    expect(result["total"]).to be_a(Integer)
    expect(result["page"]).to be_a(Integer)
    expect(result["totalPages"]).to be_a(Integer)
  end

  it "should list contacts with pagination" do
    result = $sevk.contacts.list(page: 1, limit: 5)

    expect(result).to be_a(Hash)
    expect(result["page"]).to eq(1)
  end

  it "should create a contact with required fields" do
    email = "test-#{unique_id}@example.com"
    result = $sevk.contacts.create(email: email)

    expect(result).to be_a(Hash)
    expect(result["id"]).not_to be_nil
    expect(result["id"]).to be_a(String)
    expect(result["email"]).to eq(email)
    expect([true, false]).to include(result["subscribed"])
    expect(result["createdAt"]).not_to be_nil
    expect(result["updatedAt"]).not_to be_nil
  end

  it "should get a contact by id" do
    email = "get-test-#{unique_id}@example.com"
    contact = $sevk.contacts.create(email: email)
    result = $sevk.contacts.get(contact["id"])

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq(contact["id"])
    expect(result["email"]).not_to be_nil
  end

  it "should update a contact" do
    email = "update-test-#{unique_id}@example.com"
    contact = $sevk.contacts.create(email: email)

    result = $sevk.contacts.update(contact["id"], subscribed: false)

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq(contact["id"])
    expect(result["subscribed"]).to eq(false)
  end

  it "should throw error for non-existent contact" do
    expect { $sevk.contacts.get("non-existent-id") }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end

  it "should delete a contact" do
    email = "delete-test-#{unique_id}@example.com"
    contact = $sevk.contacts.create(email: email)

    $sevk.contacts.delete(contact["id"])

    expect { $sevk.contacts.get(contact["id"]) }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end
end

# ============================================
# AUDIENCES TESTS
# ============================================
RSpec.describe "Audiences" do
  it "should list audiences with correct response structure" do
    result = $sevk.audiences.list

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
    expect(result["total"]).to be_a(Integer)
    expect(result["page"]).to be_a(Integer)
    expect(result["totalPages"]).to be_a(Integer)
  end

  it "should create and delete an audience" do
    name = "Test Audience #{unique_id}"
    result = $sevk.audiences.create(name: name)

    expect(result).to be_a(Hash)
    expect(result["id"]).not_to be_nil
    expect(result["id"]).to be_a(String)
    expect(result["name"]).to eq(name)
    expect(result["createdAt"]).not_to be_nil
    expect(result["updatedAt"]).not_to be_nil

    # Delete immediately to free up limit
    $sevk.audiences.delete(result["id"])

    expect { $sevk.audiences.get(result["id"]) }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end

  it "should get an audience by id" do
    audience_id = get_shared_audience
    result = $sevk.audiences.get(audience_id)

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq(audience_id)
  end

  it "should update an audience" do
    audience_id = get_shared_audience
    new_name = "Updated Audience #{unique_id}"
    result = $sevk.audiences.update(audience_id, name: new_name)

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq(audience_id)
    expect(result["name"]).to eq(new_name)
  end

  it "should add contacts to audience" do
    audience_id = get_shared_audience
    contact = $sevk.contacts.create(email: "add-contacts-#{unique_id}@example.com")

    result = $sevk.audiences.add_contacts(audience_id, [contact["id"]])
    expect(result).not_to be_nil
  end
end

# ============================================
# TEMPLATES TESTS
# ============================================
RSpec.describe "Templates" do
  it "should list templates with correct response structure" do
    result = $sevk.templates.list

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
    expect(result["total"]).to be_a(Integer)
    expect(result["page"]).to be_a(Integer)
    expect(result["totalPages"]).to be_a(Integer)
  end

  it "should create a template with required fields" do
    title = "Test Template #{unique_id}"
    result = $sevk.templates.create(
      title: title,
      content: "<p>Hello {{name}}</p>"
    )

    expect(result).to be_a(Hash)
    expect(result["id"]).not_to be_nil
    expect(result["id"]).to be_a(String)
    expect(result["title"]).to eq(title)
    expect(result["content"]).to eq("<p>Hello {{name}}</p>")
    expect(result["createdAt"]).not_to be_nil
    expect(result["updatedAt"]).not_to be_nil
  end

  it "should get a template by id" do
    template = $sevk.templates.create(title: "Get Test #{unique_id}", content: "<p>Test</p>")
    result = $sevk.templates.get(template["id"])

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq(template["id"])
  end

  it "should update a template" do
    template = $sevk.templates.create(title: "Update Test #{unique_id}", content: "<p>Test</p>")
    new_title = "Updated Template #{unique_id}"
    result = $sevk.templates.update(template["id"], title: new_title)

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq(template["id"])
    expect(result["title"]).to eq(new_title)
  end

  it "should duplicate a template" do
    template = $sevk.templates.create(title: "Duplicate Test #{unique_id}", content: "<p>Test</p>")
    result = $sevk.templates.duplicate(template["id"])

    expect(result).to be_a(Hash)
    expect(result["id"]).not_to be_nil
    expect(result["id"]).not_to eq(template["id"])
  end

  it "should delete a template" do
    template = $sevk.templates.create(
      title: "Delete Test #{unique_id}",
      content: "<p>Test</p>"
    )

    $sevk.templates.delete(template["id"])

    expect { $sevk.templates.get(template["id"]) }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end
end

# ============================================
# BROADCASTS TESTS
# ============================================
RSpec.describe "Broadcasts" do
  it "should list broadcasts with correct response structure" do
    result = $sevk.broadcasts.list

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
    expect(result["total"]).to be_a(Integer)
    expect(result["page"]).to be_a(Integer)
    expect(result["totalPages"]).to be_a(Integer)
  end

  it "should list broadcasts with pagination" do
    result = $sevk.broadcasts.list(page: 1, limit: 10)

    expect(result).to be_a(Hash)
    expect(result["page"]).to eq(1)
  end

  it "should list broadcasts with search" do
    result = $sevk.broadcasts.list(search: "test")

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
  end
end

# ============================================
# DOMAINS TESTS
# ============================================
RSpec.describe "Domains" do
  it "should list domains with correct response structure" do
    result = $sevk.domains.list

    expect(result).to be_a(Hash)
    expect(result["domains"]).to be_an(Array)
  end

  it "should list only verified domains" do
    result = $sevk.domains.list(verified: true)

    expect(result).to be_a(Hash)
    expect(result["domains"]).to be_an(Array)
    result["domains"].each do |domain|
      expect(domain["verified"]).to eq(true)
    end
  end
end

# ============================================
# TOPICS TESTS (uses shared audience)
# ============================================
RSpec.describe "Topics" do
  it "should list topics for an audience" do
    audience_id = get_shared_audience
    result = $sevk.topics.list(audience_id)

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
    expect(result["total"]).to be_a(Integer)
  end

  it "should create a topic" do
    audience_id = get_shared_audience
    name = "Test Topic #{unique_id}"
    result = $sevk.topics.create(audience_id, name: name)

    expect(result).to be_a(Hash)
    expect(result["id"]).not_to be_nil
    expect(result["name"]).to eq(name)
    expect(result["audienceId"]).to eq(audience_id)
  end

  it "should get a topic by id" do
    audience_id = get_shared_audience
    topic = $sevk.topics.create(audience_id, name: "Get Test #{unique_id}")
    result = $sevk.topics.get(audience_id, topic["id"])

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq(topic["id"])
  end

  it "should update a topic" do
    audience_id = get_shared_audience
    topic = $sevk.topics.create(audience_id, name: "Update Test #{unique_id}")
    new_name = "Updated Topic #{unique_id}"
    result = $sevk.topics.update(audience_id, topic["id"], name: new_name)

    expect(result).to be_a(Hash)
    expect(result["name"]).to eq(new_name)
  end

  it "should delete a topic" do
    audience_id = get_shared_audience
    topic = $sevk.topics.create(audience_id, name: "Delete Test #{unique_id}")

    $sevk.topics.delete(audience_id, topic["id"])

    expect { $sevk.topics.get(audience_id, topic["id"]) }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end
end

# ============================================
# SEGMENTS TESTS (uses shared audience)
# ============================================
RSpec.describe "Segments" do
  it "should list segments for an audience" do
    audience_id = get_shared_audience
    result = $sevk.segments.list(audience_id)

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
    expect(result["total"]).to be_a(Integer)
  end

  it "should create a segment" do
    audience_id = get_shared_audience
    name = "Test Segment #{unique_id}"
    result = $sevk.segments.create(
      audience_id,
      name: name,
      rules: [{ "field" => "email", "operator" => "contains", "value" => "@example.com" }],
      operator: "AND"
    )

    expect(result).to be_a(Hash)
    expect(result["id"]).not_to be_nil
    expect(result["name"]).to eq(name)
    expect(result["audienceId"]).to eq(audience_id)
    expect(result["operator"]).to eq("AND")
  end

  it "should get a segment by id" do
    audience_id = get_shared_audience
    segment = $sevk.segments.create(audience_id, name: "Get Test #{unique_id}", rules: [], operator: "AND")
    result = $sevk.segments.get(audience_id, segment["id"])

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq(segment["id"])
  end

  it "should update a segment" do
    audience_id = get_shared_audience
    segment = $sevk.segments.create(audience_id, name: "Update Test #{unique_id}", rules: [], operator: "AND")
    new_name = "Updated Segment #{unique_id}"
    result = $sevk.segments.update(audience_id, segment["id"], name: new_name)

    expect(result).to be_a(Hash)
    expect(result["name"]).to eq(new_name)
  end

  it "should delete a segment" do
    audience_id = get_shared_audience
    segment = $sevk.segments.create(
      audience_id,
      name: "Delete Test #{unique_id}",
      rules: [],
      operator: "AND"
    )

    $sevk.segments.delete(audience_id, segment["id"])

    expect { $sevk.segments.get(audience_id, segment["id"]) }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end
end

# ============================================
# SUBSCRIPTIONS TESTS (uses shared audience)
# ============================================
RSpec.describe "Subscriptions" do
  it "should subscribe a contact" do
    audience_id = get_shared_audience
    email = "subscribe-test-#{unique_id}@example.com"

    expect {
      $sevk.subscriptions.subscribe(
        email: email,
        audience_id: audience_id
      )
    }.not_to raise_error
  end

  it "should unsubscribe a contact by email" do
    email = "unsubscribe-test-#{unique_id}@example.com"
    contact = $sevk.contacts.create(email: email, subscribed: true)

    $sevk.subscriptions.unsubscribe(email: email)

    updated_contact = $sevk.contacts.get(contact["id"])
    expect(updated_contact["subscribed"]).to eq(false)
  end
end

# ============================================
# EMAILS TESTS
# ============================================
RSpec.describe "Emails" do
  it "should reject email with unverified domain" do
    expect {
      $sevk.emails.send(
        to: "test@example.com",
        subject: "Test Email",
        html: "<p>Hello</p>",
        from: "no-reply@unverified-domain.com"
      )
    }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("403")
      expect(error.message.downcase).to include("domain")
      expect(error.message.downcase).to include("verified")
    end
  end

  it "should reject email with domain not owned by project" do
    expect {
      $sevk.emails.send(
        to: "test@example.com",
        subject: "Test Email",
        html: "<p>Hello</p>",
        from: "no-reply@not-my-domain.io"
      )
    }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("403")
      expect(error.message.downcase).to include("domain")
    end
  end

  it "should reject email with invalid from address" do
    expect {
      $sevk.emails.send(
        to: "test@example.com",
        subject: "Test Email",
        html: "<p>Hello</p>",
        from: "invalid-email-without-domain"
      )
    }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("400")
    end
  end

  it "should return proper error message for domain verification" do
    expect {
      $sevk.emails.send(
        to: "recipient@example.com",
        subject: "Test Email",
        html: "<p>Hello World</p>",
        from: "sender@random-unverified-domain.xyz"
      )
    }.to raise_error(Sevk::Error) do |error|
      expect(error.message).not_to be_nil
      expect(error.message.length).to be > 0

      lower_message = error.message.downcase
      expect(
        lower_message.include?("domain") ||
        lower_message.include?("verified") ||
        lower_message.include?("forbidden")
      ).to be true
    end
  end
end

# ============================================
# ERROR HANDLING TESTS
# ============================================
RSpec.describe "Error Handling" do
  it "should handle 404 errors gracefully" do
    expect { $sevk.contacts.get("non-existent-id-12345") }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end

  it "should handle validation errors" do
    expect { $sevk.contacts.create(email: "invalid-email") }.to raise_error(Sevk::Error)
  end
end

# ============================================
# MARKUP RENDERER TESTS
# ============================================
RSpec.describe "Markup Renderer" do
  it "should return HTML document structure" do
    html = Sevk::Markup.render("<email><body></body></email>")
    expect(html).to include("<!DOCTYPE html")
    expect(html).to include("<html")
    expect(html).to include("<head>")
    expect(html).to include("<body")
    expect(html).to include("</html>")
  end

  it "should include meta tags" do
    html = Sevk::Markup.render("<email><body></body></email>")
    expect(html).to include("charset=UTF-8")
    expect(html).to include("viewport")
  end

  it "should include title when provided" do
    markup = "<email><head><title>Test Email</title></head><body></body></email>"
    html = Sevk::Markup.render(markup)
    expect(html).to include("<title>Test Email</title>")
  end

  it "should include preview text when provided" do
    markup = "<email><head><preview>Preview text here</preview></head><body></body></email>"
    html = Sevk::Markup.render(markup)
    expect(html).to include("Preview text here")
    expect(html).to include("display:none")
  end

  it "should include custom styles when provided" do
    markup = "<email><head><style>.custom { color: red; }</style></head><body></body></email>"
    html = Sevk::Markup.render(markup)
    expect(html).to include(".custom { color: red; }")
  end

  it "should render empty markup with document structure" do
    html = Sevk::Markup.render("")
    expect(html).to include("<!DOCTYPE html")
    expect(html).to include("<body")
  end

  it "should have default body styles" do
    html = Sevk::Markup.render("<email><body></body></email>")
    expect(html).to include("margin:0")
    expect(html).to include("padding:0")
    expect(html).to include("font-family")
  end

  it "should include html lang attribute" do
    html = Sevk::Markup.render("<email><body></body></email>")
    expect(html).to include('lang="en"')
  end

  it "should include html dir attribute" do
    html = Sevk::Markup.render("<email><body></body></email>")
    expect(html).to include('dir="ltr"')
  end

  it "should include Content-Type meta tag" do
    html = Sevk::Markup.render("<email><body></body></email>")
    expect(html).to include("Content-Type")
    expect(html).to include("text/html")
  end

  it "should include XHTML doctype" do
    html = Sevk::Markup.render("<email><body></body></email>")
    expect(html).to include("XHTML 1.0 Transitional")
  end

  it "should include background-color in body styles" do
    html = Sevk::Markup.render("<email><body></body></email>")
    expect(html).to include("background-color")
  end

  it "should render mail tag same as email tag" do
    html = Sevk::Markup.render("<mail><body></body></mail>")
    expect(html).to include("<!DOCTYPE html")
    expect(html).to include("<body")
  end

  it "should handle complex markup structure" do
    markup = "<email>
      <head>
        <title>Complex Email</title>
        <preview>This is a preview</preview>
        <style>.test { color: blue; }</style>
      </head>
      <body></body>
    </email>"
    html = Sevk::Markup.render(markup)
    expect(html).to include("Complex Email")
    expect(html).to include("This is a preview")
    expect(html).to include(".test { color: blue; }")
  end

  it "should include font links when provided" do
    markup = '<email><head><font name="Roboto" url="https://fonts.googleapis.com/css?family=Roboto" /></head><body></body></email>'
    html = Sevk::Markup.render(markup)
    expect(html).to include("fonts.googleapis.com")
  end

  it "should handle multiple fonts" do
    markup = '<email><head>
      <font name="Roboto" url="https://fonts.googleapis.com/css?family=Roboto" />
      <font name="Open Sans" url="https://fonts.googleapis.com/css?family=Open+Sans" />
    </head><body></body></email>'
    html = Sevk::Markup.render(markup)
    expect(html).to include("Roboto")
    expect(html).to include("Open+Sans")
  end

  it "should handle whitespace in markup" do
    markup = "   <email>   <body>   </body>   </email>   "
    html = Sevk::Markup.render(markup)
    expect(html).to include("<!DOCTYPE html")
    expect(html).to include("<body")
  end

  it "should return string type" do
    html = Sevk::Markup.render("<email><body></body></email>")
    expect(html).to be_a(String)
    expect(html.length).to be > 0
  end
end
