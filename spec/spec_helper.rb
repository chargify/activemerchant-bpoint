require 'rubygems'
require 'activemerchant-bpoint'
require 'support/gateway_helpers'
require 'webmock/rspec'
require 'vcr'
require 'test_credentials'

RSpec.configure do |config|
  config.include GatewayHelpers
end

VCR.configure do |c|
  c.cassette_library_dir = File.dirname(__FILE__) + '/support/vcr_cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data('<ns0:username>[GATEWAY_LOGIN]</ns0:username>') { "<ns0:username>#{GATEWAY_LOGIN}</ns0:username>" }
  c.filter_sensitive_data('<ns0:password>[GATEWAY_PASSWORD]</ns0:password>') { "<ns0:password>#{GATEWAY_PASSWORD}</ns0:password>" }
  c.filter_sensitive_data('<ns0:merchantNumber>[GATEWAY_MERCHANT_NUMBER]</ns0:merchantNumber>') { "<ns0:merchantNumber>#{GATEWAY_MERCHANT_NUMBER}</ns0:merchantNumber>" }
  c.filter_sensitive_data('<ns0:username>[PREAUTH_GATEWAY_LOGIN]</ns0:username>') { "<ns0:username>#{PREAUTH_GATEWAY_LOGIN}</ns0:username>" }
  c.filter_sensitive_data('<ns0:password>[PREAUTH_GATEWAY_PASSWORD]</ns0:password>') { "<ns0:password>#{PREAUTH_GATEWAY_PASSWORD}</ns0:password>" }
  c.filter_sensitive_data('<ns0:merchantNumber>[PREAUTH_GATEWAY_MERCHANT_NUMBER]</ns0:merchantNumber>') { "<ns0:merchantNumber>#{PREAUTH_GATEWAY_MERCHANT_NUMBER}</ns0:merchantNumber>" }
end
