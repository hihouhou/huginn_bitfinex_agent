module Agents
  class BitfinexAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description <<-MD
      The Bitfinex Agent interacts with the Bitfinex API and can create events / tasks if wanted / needed.

      The `type` can be like checking the wallet's balance, alerts.

      `apikey` is needed for auth endpoint.

      `secretkey` is needed for auth endpoint.

      `debug` is for adding verbosity.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
    MD

    event_description <<-MD
      Events look like this:

          {
            "wallet_type": "exchange",
            "currency": "CLO",
            "balance": 10000000.0000000,
            "unsettled_interest": 0,
            "available_balance": 0.0000000000000000,
            "last_change": null,
            "trade_details": null
          }
    MD

    def default_options
      {
        'type' => '',
        'apikey' => '',
        'secretkey' => '',
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :debug, type: :boolean
    form_configurable :apikey, type: :string
    form_configurable :secretkey, type: :string
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :type, type: :array, values: ['get_balances', 'alerts_list']
    def validate_options
      errors.add(:base, "type has invalid value: should be 'get_balances' 'alerts_list'") if interpolated['type'].present? && !%w(get_balances alerts_list).include?(interpolated['type'])

      unless options['apikey'].present? || !['get_balances', 'alerts_list'].include?(options['type'])
        errors.add(:base, "apikey is a required field")
      end

      unless options['secretkey'].present? || !['get_balances', 'alerts_list'].include?(options['type'])
        errors.add(:base, "secretkey is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      trigger_action
    end

    private

    def sign(payload)
      OpenSSL::HMAC.hexdigest('sha384', interpolated['secretkey'], payload)
    end

    def new_nonce
      (Time.now.to_f * 1000000).floor.to_s
    end

    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "body"
        log body
      end

    end

    def alerts_list(base_url)
      nonce = new_nonce
      body = '{type: "price"}'
      bitfinex_payload = "/api/v2/auth/r/alerts#{nonce}#{body.to_json}"

      url = "#{base_url}/v2/auth/r/alerts"
      uri = URI.parse(url)
      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      request["bfx-nonce"] = nonce
      request["bfx-apikey"] = interpolated['apikey'] 
      request["bfx-signature"] = sign(bitfinex_payload)
      request.set_form_data(body.to_json)
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)
      payload = JSON.parse(response.body)
# IN PROGRESS
#      if interpolated['changes_only'] == 'true'
#        if payload.to_s != memory['last_status']
#          if "#{memory['last_status']}" == ''
#            payload.each do | wallet_type, currency, balance, unsettled_interest, available_balance, last_change, trade_details|
#              create_event :payload => { 'wallet_type' => wallet_type, 'currency' => currency, 'balance' => balance,'unsettled_interest' => unsettled_interest, 'available_balance' => available_balance, 'last_change' => last_change, 'trade_details' => trade_details}
#            end
#          else
#            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,")
#            last_status = JSON.parse(last_status)
#            payload.each do | wallet_type, currency, balance, unsettled_interest, available_balance, last_change, trade_details|
#              found = false
#              last_status.each do | wallet_typebis, currencybis, balancebis, unsettled_interestbis, available_balancebis, last_changebis, trade_detailsbis|
#                if wallet_type == wallet_typebis && currency == currencybis && balance == balancebis
#                    found = true
#                end
#              end
#              if found == false
#                  create_event :payload => { 'wallet_type' => wallet_type, 'currency' => currency, 'balance' => balance,'unsettled_interest' => unsettled_interest, 'available_balance' => available_balance, 'last_change' => last_change, 'trade_details' => trade_details}
#              end
#            end
#          end
#          memory['last_status'] = payload.to_s
#        end
#      else
#        create_event payload: payload
#        if payload.to_s != memory['last_status']
#          memory['last_status'] = payload.to_s
#        end
#      end
    end

    def get_balances(base_url)
      nonce = new_nonce
      body = ''
      bitfinex_payload = "/api/v2/auth/r/wallets#{nonce}#{body}"

      url = "#{base_url}/v2/auth/r/wallets"
      uri = URI.parse(url)
      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      request["bfx-nonce"] = nonce
      request["bfx-apikey"] = interpolated['apikey'] 
      request["bfx-signature"] = sign(bitfinex_payload)
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)
      payload = JSON.parse(response.body)
      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload.each do | wallet_type, currency, balance, unsettled_interest, available_balance, last_change, trade_details|
              create_event :payload => { 'wallet_type' => wallet_type, 'currency' => currency, 'balance' => balance,'unsettled_interest' => unsettled_interest, 'available_balance' => available_balance, 'last_change' => last_change, 'trade_details' => trade_details}
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,")
            last_status = JSON.parse(last_status)
            payload.each do | wallet_type, currency, balance, unsettled_interest, available_balance, last_change, trade_details|
              found = false
              last_status.each do | wallet_typebis, currencybis, balancebis, unsettled_interestbis, available_balancebis, last_changebis, trade_detailsbis|
                if wallet_type == wallet_typebis && currency == currencybis && balance == balancebis
                    found = true
                end
              end
              if found == false
                  create_event :payload => { 'wallet_type' => wallet_type, 'currency' => currency, 'balance' => balance,'unsettled_interest' => unsettled_interest, 'available_balance' => available_balance, 'last_change' => last_change, 'trade_details' => trade_details}
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end

    def trigger_action()

      base_url = 'https://api.bitfinex.com'
      case interpolated['type']
      when "get_balances"
        get_balances(base_url)
      when "alerts_list"
        alerts_list(base_url)
      else
        log "Error: type has an invalid value (#{type})"
      end
    end
  end
end
