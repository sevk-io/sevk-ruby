> [!WARNING]
> Sevk is currently in private beta. This SDK is not yet available for public use.
> Join the waitlist at [sevk.io](https://sevk.io) to get early access.

<p align="center">
  <img src="https://sevk.io/logo.png" alt="Sevk" width="120" />
</p>

<h1 align="center">Sevk Ruby SDK</h1>

<p align="center">
  Official Ruby SDK for <a href="https://sevk.io">Sevk</a> email platform.
</p>

<p align="center">
  <a href="https://docs.sevk.io">Documentation</a> •
  <a href="https://sevk.io">Website</a>
</p>

## Installation

```bash
gem install sevk
```

## Send Email

```ruby
require 'sevk'

client = Sevk::Client.new('your-api-key')

client.emails.send(
  to: 'recipient@example.com',
  from: 'hello@yourdomain.com',
  subject: 'Hello from Sevk!',
  html: '<h1>Welcome!</h1>'
)
```

## Send Email with Markup

```ruby
require 'sevk'

client = Sevk::Client.new('your-api-key')

html = Sevk::Markup.render(<<~MARKUP
  <section padding="40px 20px" background-color="#f8f9fa">
    <container max-width="600px">
      <heading level="1" color="#1a1a1a">Welcome!</heading>
      <paragraph color="#666666">Thanks for signing up.</paragraph>
      <button href="https://example.com" background-color="#5227FF" color="#ffffff" padding="12px 24px">
        Get Started
      </button>
    </container>
  </section>
MARKUP
)

client.emails.send(
  to: 'recipient@example.com',
  from: 'hello@yourdomain.com',
  subject: 'Welcome!',
  html: html
)
```

## Documentation

For full documentation, visit [docs.sevk.io](https://docs.sevk.io)

## License

MIT
