require 'rubygems'
require 'activemerchant-bpoint'
require 'support/gateway_helpers'
require 'vcr'
require 'test_credentials'

RSpec.configure do |config|
  config.include GatewayHelpers
end

VCR.config do |c|
  c.cassette_library_dir = File.dirname(__FILE__) + '/support/vcr_cassettes'
  c.stub_with :fakeweb
  c.filter_sensitive_data('<ns0:username>[GATEWAY_LOGIN]</ns0:username>') { "<ns0:username>#{GATEWAY_LOGIN}</ns0:username>" }
  c.filter_sensitive_data('<ns0:password>[GATEWAY_PASSWORD]</ns0:password>') { "<ns0:password>#{GATEWAY_PASSWORD}</ns0:password>" }
  c.filter_sensitive_data('<ns0:merchantNumber>[GATEWAY_MERCHANT_NUMBER]</ns0:merchantNumber>') { "<ns0:merchantNumber>#{GATEWAY_MERCHANT_NUMBER}</ns0:merchantNumber>" }
end
