module GatewayHelpers
  def credit_card(number = '5123456789012346', options = {})
    defaults = {
      :number => number,
      :month => 99,  # We need to use 99 to trigger 'Test' mode for the gatewqy
      :year => 2000, # In gateway test mode the year is used to set the response status, (2000 in YY == 00 which is approved)
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :verification_value => '123',
      :type => 'visa'
    }.update(options)

    ActiveMerchant::Billing::CreditCard.new(defaults)
  end

  def gateway(options = {})
    ActiveMerchant::Billing::BpointGateway.new({ :login => GATEWAY_LOGIN, :password => GATEWAY_PASSWORD, :merchant_number => GATEWAY_MERCHANT_NUMBER }.merge(options))
  end

  def gateway_with_preauth(options = {})
    normal_credentials  = { :login => GATEWAY_LOGIN, :password => GATEWAY_PASSWORD, :merchant_number => GATEWAY_MERCHANT_NUMBER }
    preauth_credentials = { :preauth_login => PREAUTH_GATEWAY_LOGIN, :preauth_password => PREAUTH_GATEWAY_PASSWORD, :preauth_merchant_number => PREAUTH_GATEWAY_MERCHANT_NUMBER }
    ActiveMerchant::Billing::BpointGateway.new(normal_credentials.merge(preauth_credentials).merge(options))
  end
end
