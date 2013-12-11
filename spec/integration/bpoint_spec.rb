require 'spec_helper'

describe ActiveMerchant::Billing::BpointGateway do
  let(:options)             { { :order_id => '1', :description => 'Store Purchase' } }
  let(:success_credit_card) { credit_card('5123456789012346', :year => 2100) }
  let(:fail_credit_card)    { credit_card('5123456789012346', :year => 2054) }
  let(:invalid_credit_card) { credit_card('', :year => 2010) }

  context 'using invalid details' do
    let(:my_gateway) { gateway(:login => 'does', :password => 'not_exist', :merchant_number => '8') }
    let(:response)   { VCR.use_cassette('invalid login') { my_gateway.purchase(100, credit_card, options) } }

    it 'is not successful' do
      response.should_not be_success
    end

    it 'returns an invalid login status' do
      response.message.should include 'invalid login'
    end
  end

  context 'making a purchase' do
    context 'on a valid credit card' do
      subject { VCR.use_cassette('valid CC purchase') { gateway.purchase(1000, success_credit_card, options) } }

      it { should be_success }

      it 'should return an authorization ID' do
        subject.authorization.should be_present
      end

      it 'returns an "Approved" message' do
        subject.message.should eql 'Approved'
      end
    end

    context 'on an invalid credit card' do
      subject { VCR.use_cassette('invalid CC purchase') { gateway.purchase(1000, fail_credit_card, options) } }

      it { should_not be_success }

      it 'returns a "Declined" message' do
        subject.message.should eql 'Declined'
      end
    end
  end

  context 'making a purchase with a stored credit card' do
    let!(:token)  { VCR.use_cassette('store valid CC') { gateway.store(success_credit_card).params['billingid'] } }

    context 'with a valid token' do
      subject { VCR.use_cassette('valid token purchase') { gateway.purchase(1000, token, options) } }

      it { should be_success }

      it 'should return an authorization ID' do
        subject.authorization.should be_present
      end

      it 'returns an "Approved" message' do
        subject.message.should eql 'Approved'
      end
    end

    context 'on an invalid token' do
      subject { VCR.use_cassette('invalid token purchase') { gateway.purchase(1000, 'invalid', options) } }

      it { should_not be_success }

      it 'returns an "unable to determine card type" message' do
        subject.message.should eql 'unable to determine card type'
      end
    end

  end

  context 'storing a credit card' do
    context 'for a valid credit card' do
      subject { VCR.use_cassette('store valid CC') { gateway.store(success_credit_card) } }

      it { should be_success }

      it 'should return a token' do
        subject.params['billingid'].should be_present
      end
    end

    context 'for an invalid credit card' do
      subject { VCR.use_cassette('store invalid CC') { gateway.store(invalid_credit_card) } }

      it { should_not be_success }

      it 'returns an "invalid card number: no value" message' do
        subject.message.should eql 'invalid card number: no value'
      end
    end
  end

  context 'removing a credit card from storage' do
    let!(:token)  { VCR.use_cassette('store valid CC for removal') { gateway.store(success_credit_card).params['billingid'] } }

    context 'when given a valid token' do
      subject { VCR.use_cassette('unstore valid token') { gateway.unstore(token) } }

      it { should be_success }
    end

    context 'when not given a valid token' do
      subject { VCR.use_cassette('unstore invalid token') { gateway.unstore('7') } }

      it { should_not be_success }

      it 'returns an "invalid token" message' do
        subject.message.should eql 'invalid token'
      end
    end
  end

  context 'attempting to charge a removed token' do
    let!(:token)  { VCR.use_cassette('store valid CC for removal') { gateway.store(success_credit_card).params['billingid'] } }
    before        { VCR.use_cassette('unstore valid token') { gateway.unstore(token) } }
    subject       { VCR.use_cassette('invalid token purchase against unstored card') { gateway.purchase(1000, token, options) } }

    it { should_not be_success }

    it 'returns an "Payment details not found" message' do
      subject.message.should eql 'Payment details not found'
    end
  end

  context 'performing a pre-authorization against a credit card' do
    context 'using a gateway without pre-auth facility credentials' do
      it 'should raise an ArgumentError' do
        expect { gateway.authorize(1000, success_credit_card) }.to raise_error(ArgumentError, "Missing required parameter: preauth_login")
      end
    end

    context 'using a gateway with pre-auth facility credentials' do
      context 'on a valid credit card' do
        subject { VCR.use_cassette('valid CC authorization') { gateway_with_preauth.authorize(1000, success_credit_card, options) } }

        it 'uses the pre-auth facility credentials' do
          subject
          WebMock.should have_requested(:post, 'https://www.bpoint.com.au/evolve/service.asmx').with { |req|
            req.body.include? "<ns0:merchantNumber>#{PREAUTH_GATEWAY_MERCHANT_NUMBER}</ns0:merchantNumber>"
          }
        end

        it { should be_success }

        it 'should return an authorization ID' do
          subject.authorization.should be_present
        end

        it 'returns an "Approved" message' do
          subject.message.should eql 'Approved'
        end
      end

      context 'on an invalid credit card' do
        subject { VCR.use_cassette('invalid CC authorization') { gateway_with_preauth.authorize(1000, fail_credit_card, options) } }

        it { should_not be_success }

        it 'returns a "Declined" message' do
          subject.message.should eql 'Declined'
        end
      end
    end
  end
end
