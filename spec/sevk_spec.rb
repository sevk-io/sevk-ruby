# frozen_string_literal: true

require "spec_helper"

DEFAULT_BASE_URL = "https://api.sevk.io"

def unique_id
  "#{Time.now.to_i}#{rand(10000)}"
end

def base_url
  ENV["SEVK_TEST_BASE_URL"] || DEFAULT_BASE_URL
end

# Global test data
$sevk = nil
$shared_audience_id = nil
$created_broadcast_id = nil
$created_domain_id = nil

# Helper to get or create shared audience
def get_shared_audience
  return $shared_audience_id if $shared_audience_id
  audience = $sevk.audiences.create(name: "Shared Test Audience #{unique_id}")
  $shared_audience_id = audience["id"]
  $shared_audience_id
end

RSpec.configure do |config|
  api_key = ENV["SEVK_TEST_API_KEY"]

  unless api_key && !api_key.empty?
    config.filter_run_excluding integration: true
    next
  end

  config.before(:suite) do
    $sevk = Sevk::Client.new(api_key: ENV["SEVK_TEST_API_KEY"], base_url: base_url)
  end
end

# ============================================
# AUTHENTICATION TESTS
# ============================================
RSpec.describe "Authentication", integration: true do
  it "should reject invalid API key" do
    invalid_client = Sevk::Client.new(api_key: "sevk_invalid_api_key_12345", base_url: base_url)
    expect { invalid_client.contacts.list }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("401")
      expect(error.message.downcase).to include("invalid")
    end
  end

  it "should reject empty API key" do
    empty_client = Sevk::Client.new(api_key: "", base_url: base_url)
    expect { empty_client.contacts.list }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("401")
    end
  end

  it "should reject malformed API key (not starting with sevk_)" do
    malformed_client = Sevk::Client.new(api_key: "invalid_key_format", base_url: base_url)
    expect { malformed_client.contacts.list }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("401")
    end
  end
end

# ============================================
# CONTACTS TESTS
# ============================================
RSpec.describe "Contacts", integration: true do
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

  it "should bulk update contacts" do
    email = "bulk-update-#{unique_id}@example.com"
    contact = $sevk.contacts.create(email: email)

    result = $sevk.contacts.bulk_update(
      contacts: [{ email: contact["email"], subscribed: true }]
    )

    expect(result).not_to be_nil
  end

  it "should get contact events" do
    email = "events-test-#{unique_id}@example.com"
    contact = $sevk.contacts.create(email: email)

    result = $sevk.contacts.get_events(contact["id"])

    expect(result).not_to be_nil
  end

  it "should import contacts" do
    email = "import-test-#{unique_id}@example.com"
    result = $sevk.contacts.import_csv(
      contacts: [{ email: email }]
    )

    expect(result).not_to be_nil
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
RSpec.describe "Audiences", integration: true do
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

  it "should create an audience with all fields" do
    name = "Full Audience #{unique_id}"
    result = $sevk.audiences.create(
      name: name,
      description: "Test description",
      users_can_see: "PUBLIC"
    )

    expect(result).to be_a(Hash)
    expect(result["name"]).to eq(name)
    expect(result["description"]).to eq("Test description")
    expect(result["usersCanSee"]).to eq("PUBLIC")

    # Cleanup
    $sevk.audiences.delete(result["id"])
  end

  it "should add contacts to audience" do
    audience_id = get_shared_audience
    contact = $sevk.contacts.create(email: "add-contacts-#{unique_id}@example.com")

    result = $sevk.audiences.add_contacts(audience_id, [contact["id"]])
    expect(result).not_to be_nil
  end

  it "should list contacts in an audience" do
    audience_id = get_shared_audience
    result = $sevk.audiences.list_contacts(audience_id)

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
  end

  it "should remove a contact from an audience" do
    audience_id = get_shared_audience

    # Create a contact and add to audience, then remove
    email = "audience-remove-test-#{unique_id}@example.com"
    contact = $sevk.contacts.create(email: email)
    $sevk.audiences.add_contacts(audience_id, [contact["id"]])

    $sevk.audiences.remove_contact(audience_id, contact["id"])

    # Verify removal by listing contacts
    result = $sevk.audiences.list_contacts(audience_id)
    contact_ids = result["items"].map { |c| c["id"] }
    expect(contact_ids).not_to include(contact["id"])
  end
end

# ============================================
# TEMPLATES TESTS
# ============================================
RSpec.describe "Templates", integration: true do
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
RSpec.describe "Broadcasts", integration: true, order: :defined do
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

  it "should get broadcast status" do
    result = $sevk.broadcasts.list(limit: 1)
    next if result["items"].empty?

    broadcast = result["items"].first
    status = $sevk.broadcasts.get_status(broadcast["id"])

    expect(status).to be_a(Hash)
  end

  it "should get broadcast emails" do
    result = $sevk.broadcasts.list(limit: 1)
    next if result["items"].empty?

    broadcast = result["items"].first
    emails = $sevk.broadcasts.get_emails(broadcast["id"])

    expect(emails).to be_a(Hash)
    expect(emails["items"]).to be_an(Array)
  end

  it "should estimate broadcast cost" do
    result = $sevk.broadcasts.list(limit: 1)
    next if result["items"].empty?

    broadcast = result["items"].first
    estimate = $sevk.broadcasts.estimate_cost(broadcast["id"])

    expect(estimate).to be_a(Hash)
  end

  it "should list active broadcasts" do
    result = $sevk.broadcasts.list_active

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
  end

  it "should create a broadcast" do
    # Get a domain from the project to use for broadcast
    domains = $sevk.domains.list
    next if domains["items"].empty?

    domain_id = domains["items"].first["id"]
    name = "Test Broadcast #{unique_id}"
    result = $sevk.broadcasts.create(
      domainId: domain_id,
      name: name,
      subject: "Test Subject",
      body: "<section><paragraph>Test broadcast body</paragraph></section>",
      senderName: "Test Sender",
      senderEmail: "test",
      targetType: "ALL"
    )

    expect(result).to be_a(Hash)
    expect(result["id"]).not_to be_nil
    expect(result["id"]).to be_a(String)
    expect(result["name"]).to eq(name)
    expect(result["subject"]).to eq("Test Subject")
    expect(result["status"]).to eq("DRAFT")

    $created_broadcast_id = result["id"]
  end

  it "should get a broadcast by id" do
    next unless $created_broadcast_id

    result = $sevk.broadcasts.get($created_broadcast_id)

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq($created_broadcast_id)
    expect(result["subject"]).to eq("Test Subject")
  end

  it "should update a broadcast" do
    next unless $created_broadcast_id

    new_name = "Updated Broadcast #{unique_id}"
    result = $sevk.broadcasts.update($created_broadcast_id, name: new_name)

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq($created_broadcast_id)
    expect(result["name"]).to eq(new_name)
  end

  it "should get broadcast analytics" do
    next unless $created_broadcast_id

    result = $sevk.broadcasts.get_analytics($created_broadcast_id)

    expect(result).not_to be_nil
  end

  it "should send a test broadcast" do
    next unless $created_broadcast_id

    begin
      result = $sevk.broadcasts.send_test($created_broadcast_id, emails: ["test@example.com"])
      expect(result).not_to be_nil
    rescue Sevk::Error => e
      # May fail if domain is unverified, which is expected
      expect(e.message).not_to be_nil
    end
  end

  it "should handle send error for draft broadcast" do
    next unless $created_broadcast_id

    begin
      $sevk.broadcasts.send($created_broadcast_id)
      # If it succeeds, that's fine too
    rescue Sevk::Error => e
      # Expected to fail if broadcast is not ready to send
      expect(e.message).not_to be_nil
      expect(e.message.length).to be > 0
    end
  end

  it "should handle cancel for a non-sending broadcast" do
    next unless $created_broadcast_id

    begin
      $sevk.broadcasts.cancel($created_broadcast_id)
    rescue Sevk::Error => e
      # Expected to fail if broadcast is not in a cancellable state
      expect(e.message).not_to be_nil
    end
  end

  it "should delete a broadcast" do
    next unless $created_broadcast_id

    $sevk.broadcasts.delete($created_broadcast_id)

    # Verify deletion
    expect { $sevk.broadcasts.get($created_broadcast_id) }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end
end

# ============================================
# DOMAINS TESTS
# ============================================
RSpec.describe "Domains", integration: true do
  before(:each) { skip "INCLUDE_DOMAIN_TESTS not set" unless ENV['INCLUDE_DOMAIN_TESTS'] == 'true' }

  it "should list domains with correct response structure" do
    result = $sevk.domains.list

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
  end

  it "should list only verified domains" do
    result = $sevk.domains.list(verified: true)

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
    result["items"].each do |domain|
      expect(domain["verified"]).to eq(true)
    end
  end

  it "should update a domain" do
    result = $sevk.domains.list
    expect(result["items"]).to be_an(Array)

    next if result["items"].empty?

    domain = result["items"].first
    updated = $sevk.domains.update(domain["id"], { click_tracking: !domain["clickTracking"] })

    expect(updated).to be_a(Hash)
    expect(updated["id"]).to eq(domain["id"])
  end

  it "should create a domain" do
    subdomain = "test-#{unique_id}-#{rand(36**7).to_s(36)}.example.com"
    result = $sevk.domains.create(domain: subdomain, email: "test@#{subdomain}")

    expect(result).to be_a(Hash)
    expect(result["id"]).not_to be_nil
    expect(result["id"]).to be_a(String)
    expect(result["domain"]).to eq(subdomain)

    $created_domain_id = result["id"]
  end

  it "should get a domain by id" do
    next unless $created_domain_id

    result = $sevk.domains.get($created_domain_id)

    expect(result).to be_a(Hash)
    expect(result["id"]).to eq($created_domain_id)
  end

  it "should get DNS records for a domain" do
    next unless $created_domain_id

    result = $sevk.domains.get_dns_records($created_domain_id)

    expect(result).not_to be_nil
    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
  end

  it "should get available regions" do
    result = $sevk.domains.get_regions

    expect(result).not_to be_nil
  end

  it "should verify a domain" do
    next unless $created_domain_id

    begin
      result = $sevk.domains.verify($created_domain_id)
      expect(result).not_to be_nil
    rescue Sevk::Error => e
      # Expected to fail for test domains without proper DNS records
      expect(e.message).not_to be_nil
    end
  end

  it "should delete a domain" do
    next unless $created_domain_id

    $sevk.domains.delete($created_domain_id)

    # Verify deletion
    expect { $sevk.domains.get($created_domain_id) }.to raise_error(Sevk::Error) do |error|
      expect(error.message).not_to be_nil
    end
  end
end

# ============================================
# TOPICS TESTS (uses shared audience)
# ============================================
RSpec.describe "Topics", integration: true do
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

  it "should add contacts to a topic" do
    audience_id = get_shared_audience
    topic = $sevk.topics.create(audience_id, name: "AddContacts Test #{unique_id}")
    contact = $sevk.contacts.create(email: "topic-add-#{unique_id}@example.com")
    $sevk.audiences.add_contacts(audience_id, [contact["id"]])

    result = $sevk.topics.add_contacts(audience_id, topic["id"], contact_ids: [contact["id"]])

    expect(result).not_to be_nil

    # Cleanup
    $sevk.topics.delete(audience_id, topic["id"])
  end

  it "should remove a contact from a topic" do
    audience_id = get_shared_audience
    topic = $sevk.topics.create(audience_id, name: "RemoveContact Test #{unique_id}")

    # Create a contact, add to audience and topic, then remove from topic
    email = "topic-remove-test-#{unique_id}@example.com"
    contact = $sevk.contacts.create(email: email)
    $sevk.audiences.add_contacts(audience_id, [contact["id"]])
    $sevk.topics.add_contacts(audience_id, topic["id"], contact_ids: [contact["id"]])

    $sevk.topics.remove_contact(audience_id, topic["id"], contact["id"])

    # Verify removal by listing contacts in the topic
    result = $sevk.topics.list_contacts(audience_id, topic["id"])
    contact_ids = result["items"].map { |c| c["id"] }
    expect(contact_ids).not_to include(contact["id"])

    # Cleanup
    $sevk.topics.delete(audience_id, topic["id"])
  end

  it "should list contacts for a topic" do
    audience_id = get_shared_audience
    topic = $sevk.topics.create(audience_id, name: "ListContacts Test #{unique_id}")

    result = $sevk.topics.list_contacts(audience_id, topic["id"])

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
    expect(result["total"]).to be_a(Integer)

    # Cleanup
    $sevk.topics.delete(audience_id, topic["id"])
  end
end

# ============================================
# SEGMENTS TESTS (uses shared audience)
# ============================================
RSpec.describe "Segments", integration: true do
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

  it "should calculate a segment" do
    audience_id = get_shared_audience
    segment = $sevk.segments.create(
      audience_id,
      name: "Calculate Test #{unique_id}",
      rules: [{ "field" => "email", "operator" => "contains", "value" => "@example.com" }],
      operator: "AND"
    )

    result = $sevk.segments.calculate(audience_id, segment["id"])

    expect(result).not_to be_nil

    # Cleanup
    $sevk.segments.delete(audience_id, segment["id"])
  end

  it "should preview a segment" do
    audience_id = get_shared_audience

    result = $sevk.segments.preview(audience_id,
      rules: [{ "field" => "email", "operator" => "contains", "value" => "@example.com" }],
      operator: "AND"
    )

    expect(result).not_to be_nil
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
RSpec.describe "Subscriptions", integration: true do
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
# WEBHOOKS TESTS
# ============================================
RSpec.describe "Webhooks", integration: true do
  it "should perform full CRUD cycle" do
    # Create
    webhook = $sevk.webhooks.create(
      url: "https://example.com/webhook-#{unique_id}",
      events: ["contact.subscribed"]
    )

    expect(webhook).to be_a(Hash)
    expect(webhook["id"]).not_to be_nil
    expect(webhook["url"]).to include("example.com")

    # Get
    fetched = $sevk.webhooks.get(webhook["id"])
    expect(fetched).to be_a(Hash)
    expect(fetched["id"]).to eq(webhook["id"])

    # Update
    updated = $sevk.webhooks.update(webhook["id"], url: "https://example.com/webhook-updated-#{unique_id}")
    expect(updated).to be_a(Hash)
    expect(updated["id"]).to eq(webhook["id"])

    # Delete
    $sevk.webhooks.delete(webhook["id"])

    expect { $sevk.webhooks.get(webhook["id"]) }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end

  it "should list webhooks" do
    result = $sevk.webhooks.list

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
  end

  it "should test a webhook" do
    webhook = $sevk.webhooks.create(
      url: "https://example.com/webhook-test-#{unique_id}",
      events: ["contact.subscribed"]
    )

    result = $sevk.webhooks.test(webhook["id"])
    expect(result).to be_a(Hash)

    # Cleanup
    $sevk.webhooks.delete(webhook["id"])
  end

  it "should list available webhook events" do
    result = $sevk.webhooks.list_events

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
  end
end

# ============================================
# EVENTS TESTS
# ============================================
RSpec.describe "Events", integration: true do
  it "should list events with correct response structure" do
    result = $sevk.events.list

    expect(result).to be_a(Hash)
    expect(result["items"]).to be_an(Array)
    expect(result["total"]).to be_a(Integer)
    expect(result["page"]).to be_a(Integer)
    expect(result["totalPages"]).to be_a(Integer)
  end

  it "should list events with pagination" do
    result = $sevk.events.list(page: 1, limit: 5)

    expect(result).to be_a(Hash)
    expect(result["page"]).to eq(1)
  end

  it "should get event stats" do
    result = $sevk.events.stats

    expect(result).to be_a(Hash)
  end
end

# ============================================
# USAGE TESTS
# ============================================
RSpec.describe "Usage", integration: true do
  it "should get project usage and limits" do
    result = $sevk.get_usage

    expect(result).to be_a(Hash)
    expect { Float(result["balance"]) }.not_to raise_error
    expect { Float(result["emailPrice"]) }.not_to raise_error
    expect(result["audienceLimit"]).to be_a(Integer)
    expect(result["contactLimit"]).to be_a(Integer)
    expect(result["broadcastLimit"]).to be_a(Integer)
  end
end

# ============================================
# EMAILS TESTS
# ============================================
RSpec.describe "Emails", integration: true do
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

  it "should throw error for non-existent email id" do
    expect { $sevk.emails.get("00000000-0000-0000-0000-000000000000") }.to raise_error(Sevk::Error) do |error|
      expect(error.message).to include("404")
    end
  end

  it "should reject bulk email with unverified domain" do
    result = $sevk.emails.send_bulk([
      {
        to: "test1@example.com",
        subject: "Bulk Test 1",
        html: "<p>Hello 1</p>",
        from: "no-reply@unverified-domain.com"
      },
      {
        to: "test2@example.com",
        subject: "Bulk Test 2",
        html: "<p>Hello 2</p>",
        from: "no-reply@unverified-domain.com"
      }
    ])

    expect(result).to be_a(Hash)
    expect(result["failed"]).to eq(2)
    expect(result["success"]).to eq(0)
    expect(result["errors"]).to be_an(Array)
    expect(result["errors"].length).to eq(2)
    result["errors"].each do |err|
      expect(err["error"].downcase).to include("domain")
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
RSpec.describe "Error Handling", integration: true do
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
