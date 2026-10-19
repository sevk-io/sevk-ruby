# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    class Activity < Base
      # Lists project activity with optional pagination and filtering.
      def list(page: nil, limit: nil, after: nil, before: nil, category: nil, type: nil, days: nil, search: nil)
        type = type.join(',') if type.is_a?(Array)
        params = { page: page, limit: limit, after: after, before: before, category: category, type: type, days: days,
                   search: search }

        client.get("/activity#{build_query_string(params)}")
      end

      # Returns aggregate counts and rates for recent project activity.
      def stats
        client.get('/activity/stats')
      end
    end
  end
end
