#===============================================================================
# Online - Bridge
# Requests to the bridge on this PC. Each one is short, but blocks the game
# while it runs: after a failure, the bridge is left alone for RETRY_AFTER
# seconds so that a closed bridge never slows the game down.
#===============================================================================
module Online
  module Bridge
    module_function

    # The room the bridge is in (Hash), or nil (no bridge, or not in a room).
    def state
      result = request(:get, "/state")
      return result ? result["room"] : nil
    end

    # Events of the other players after number after, and the room:
    # [events, last, room]; nil when the bridge does not answer.
    def events_after(after)
      result = request(:get, "/events?after=#{after}")
      return nil if !result
      last = result["last"] || after
      # A new bridge numbers its events from 1 again: read them all.
      return events_after(0) if last < after
      return [result["events"] || [], last, result["room"]]
    end

    # Host only: removes a player gone for KICK_AFTER seconds.
    def kick(id)
      request(:post, "/kick", { "id" => id })
    end

    # Sends data (a Hash) to the other players of the room.
    def publish(data)
      request(:post, "/event", { "data" => data })
    end

    def request(method, path, body = nil)
      return nil if @failed_at && System.uptime - @failed_at < RETRY_AFTER
      url = BRIDGE_URL + path
      response = (method == :get) ? HTTPLite.get(url) : HTTPLite.post_body(url, Json.dump(body), "application/json")
      raise "status #{response[:status]}" if !response.is_a?(Hash) || response[:status] >= 300
      @failed_at = nil
      return (response[:status] == 204) ? {} : Json.parse(response[:body])
    # mkxp-z raises MKXPError (not a StandardError) when nothing listens.
    rescue StandardError, MKXPError
      @failed_at = System.uptime
      return nil
    end

    # Asks again at once, without waiting for RETRY_AFTER.
    def retry_now
      @failed_at = nil
    end
  end
end
