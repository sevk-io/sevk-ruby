# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    # Reads project limits, resource counts, and current email usage.
    class Usage < Base
      # Returns current limits, resource counts, and inbound and outbound usage.
      def get
        client.get('/limits')
      end
    end
  end
end
