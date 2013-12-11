module ActiveMerchant
  module Billing
    class BpointGateway < Gateway
      LIVE_URL = 'https://www.bpoint.com.au/evolve/service.asmx'

      self.supported_cardtypes = [:visa, :master]
      self.supported_countries = ['AU']
      self.homepage_url        = 'http://www.bpoint.com.au'
      self.display_name        = 'BPOINT'
      self.default_currency    = 'AUD'
      self.money_format        = :cents

      def initialize(options = {})
        requires!(options, :login, :password, :merchant_number)
        @options = options
        super
      end

      # Running pre-authorizations is supported by BPOINT, but it requires the
      # use of a secondary "facility" with its own username, password, and
      # merchant number. BPOINT facilities can be configured to support either
      # PREAUTH/CAPTURE or PURCHASE, but not both.  If you wish to use support
      # for authorizations (pre-auths) then you will need to use credentials for
      # a facility with this ability.
      def authorize(money, creditcard, options = {})
        post = {:PaymentType => 'PREAUTH'}
        add_invoice(post, options)
        add_creditcard(post, creditcard, options)

        commit('ProcessPayment', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard, options)

        commit('ProcessPayment', money, post)
      end

      # Voids a prior authorization or purchase (a "reversal").
      #
      # +transaction_number+: (Required) The TransactionNumber from the transaction to reverse.
      def void(transaction_number, options = {})
        # Find the original amount via a search
        original_transaction = search({'TransactionNumber' => transaction_number})
        original_amount = if search_results = original_transaction.params['search_results']
          (search_results.first || {})['amount'].to_i
        end

        post = {
          :PaymentType => 'REVERSAL',
          :OriginalTransactionNumber => transaction_number
        }

        commit('ProcessPayment', original_amount, post)
      end

      def store(credit_card, options = {})
        post = {}
        add_creditcard(post, credit_card, options)

        commit('AddToken', nil, post)
      end

      def unstore(token, options = {})
        post = { :token => token }

        commit('DeleteToken', nil, post)
      end

      # Search Transactions.
      #
      # Search results returned as an array in response.params[:search_results]
      def search(params = {})
        commit('SearchTransactions', nil, params)
      end

      def test?
        @options[:test] || super
      end

      private

      def add_invoice(post, options)
        post[:MerchantReference] = options[:order_id]
      end

      def add_creditcard(post, creditcard_or_token, options = {})
        if creditcard_or_token.is_a?(String)
          post[:CardNumber] = creditcard_or_token
        else
          if test?
            creditcard_or_token = creditcard_or_token.dup
            creditcard_or_token.month = '99'
            creditcard_or_token.year  = '2000' if @options[:force_success] == true || options[:force_success] == true
          end
          post[:CardNumber] = creditcard_or_token.number
          post[:ExpiryDate] = "%02d%02s" % [creditcard_or_token.month, creditcard_or_token.year.to_s[-2..-1]]
          post[:CVC]        = creditcard_or_token.verification_value
          post[:CRN1]       = [creditcard_or_token.first_name, creditcard_or_token.last_name].join(' ')
        end
      end

      def parse(body)
        return {} if body.blank?

        xml    = REXML::Document.new(body)
        {}.tap { |response| xml.root.elements.to_a.each { |node| parse_element(response, node) } }
      end

      def parse_element(response, node)
        # Note: there can be two "ResponseCode" elements:
        #   1. soap:Enevelope/soap:Body/ProcessPayment/response/ResponseCode = this is the "Web Service Response Code" (i.e. "SUCCESS" or "FAILURE")
        #   2. soap:Enevelope/soap:Body/ProcessPayment/ResponseCode          = this is the "Web Method Response Code"  (i.e. "0" or "PT_T2")
        #
        # All elements beneath /response (the Web Service Response) will be nested beneath :web_service key.
        # All other elements will be un-nested.
        if node.name == 'response'
          return parse_web_service_response(response, node)
        end

        # Extract search results
        if node.name == 'SearchTransactionsResult'
          return parse_search_results(response, node)
        end

        unless node.has_elements?
          return response[:billingid] = node.text if node.name == 'Token'
          return response[node.name.underscore.to_sym] = node.text
        end

        node.elements.each{|element| parse_element(response, element) }
      end

      def parse_web_service_response(response, node)
        response[:web_service] = {}
        response[:web_service][:response_code]    = node.elements['ResponseCode'].try(:text)
        response[:web_service][:response_message] = node.elements['ResponseMessage'].try(:text)
      end

      # <SearchTransactionsResult>
      #   <Txn>...</Txn>
      #   <Txn>...</Txn>
      #   ...
      # </SearchTransactionsResult>
      def parse_search_results(response, node)
        response[:search_results] = node.to_a.map { |txn| {}.tap {|h| parse_element(h, txn) }.stringify_keys }
      end

      def commit(action, money, parameters)
        if action == 'ProcessPayment'
          parameters[:Amount]        = amount(money) if money
          parameters[:PaymentType] ||= 'PAYMENT'
          parameters[:TxnType]       = 'INTERNET_ANONYMOUS'
        end

        response = parse(ssl_post(LIVE_URL, post_data(action, parameters), 'SOAPAction' => "urn:Eve/#{action}", 'Content-Type' => 'text/xml;charset=UTF-8'))
        options  = {
          :test => test?,
          :authorization => response[:authorise_id]
        }

        Response.new(success_from(response), message_from(response), response, options)
      end

      def success_from(response)
        response[:web_service][:response_code] == 'SUCCESS' && (response[:response_code] == nil || response[:response_code] == '0')
      end

      def message_from(response)
        response[:web_service][:response_code] == 'SUCCESS' ?
          response[:authorisation_result] :
          response[:web_service][:response_message]
      end

      def post_data(action, parameters = {})
        xml      = REXML::Document.new
        envelope = xml.add_element('env:Envelope',  { 'xmlns:xsd' =>
                                  'http://www.w3.org/2001/XMLSchema',
                                    'xmlns:xsi' =>
                                  'http://www.w3.org/2001/XMLSchema-instance',
                                    'xmlns:wsdl' => 'urn:Eve', 'xmlns:env' =>
                                  'http://schemas.xmlsoap.org/soap/envelope/',
                                    'xmlns:ns0' => 'urn:Eve'})

        body    = envelope.add_element('env:Body')
        request = body.add_element("ns0:#{action}")

        tnx_request = request.add_element('ns0:tokenRequest') if action == 'AddToken'
        tnx_request = request.add_element('ns0:txnReq') if action == 'ProcessPayment'
        tnx_request = request.add_element('ns0:search') if action == 'SearchTransactions'
        tnx_request = request if tnx_request.blank?

        request.add_element('ns0:username').text       = @options[:login]
        request.add_element('ns0:password').text       = @options[:password]
        request.add_element('ns0:merchantNumber').text = @options[:merchant_number]

        parameters.each { |key, value| tnx_request.add_element("ns0:#{key}").text = value }

        xml << REXML::XMLDecl.new('1.0', 'UTF-8')
        xml.to_s
      end
    end
  end
end
