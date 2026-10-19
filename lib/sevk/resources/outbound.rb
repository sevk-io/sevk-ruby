# frozen_string_literal: true

require_relative 'base'

module Sevk
  module Resources
    # Outbound resource. Read and adjust the project's monthly outbound
    # sending cap, and pause / resume transactional sending.
    #
    # Pause affects +POST /emails+, +POST /emails/bulk+, and SMTP relay.
    # Broadcasts run on a separate balance check and are NOT affected.
    #
    # Access via +sevk.outbound+. Requires an API key with +outbound:read+
    # for +get_quota+, or +outbound:write+ for the others.
    class Outbound < Base
      # Get outbound quota settings and current usage counters.
      # Requires +outbound:read+.
      def get_quota
        client.get('/outbound-settings/quota')
      end

      # Set the user-side monthly outbound cap. Pass +monthlyEmailLimit:+
      # as a positive Integer to cap, or +nil+ to clear the user-set cap
      # (admin ceiling still applies). Raising the cap above current
      # usage clears a +monthly_cap_exhausted+ pause; does not clear
      # +manual_suspend+.
      # Requires +outbound:write+.
      def update_quota(**params)
        client.put('/outbound-settings/quota', wire_keys(params))
      end

      # Preserve the monthly counter and clear any pause (including
      # +manual_suspend+ and +balance_exhausted+). The user-set cap is
      # preserved.
      # Requires +outbound:write+.
      def reset_quota
        client.post('/outbound-settings/quota/reset', {})
      end

      # Reset custom-limit usage while preserving the cap and monthly usage.
      # Requires +outbound:write+.
      def reset_limit
        client.post('/outbound-settings/quota/reset-limit', {})
      end

      # Pause outbound transactional sending with
      # +pausedReason: manual_suspend+. Manual pauses do NOT auto-clear;
      # call +reset_quota+ to resume. Does not affect broadcasts.
      # Requires +outbound:write+.
      def pause_quota
        client.post('/outbound-settings/quota/pause', {})
      end
    end
  end
end
