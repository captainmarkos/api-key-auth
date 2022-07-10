require 'rails_helper'

RSpec.describe 'ApiKeys', type: :request do

  let(:user) { create(:user, :with_api_keys) }

  describe 'GET /api-keys' do
    context 'with no auth header' do
      it 'not authorized' do
        get '/api-keys', headers: {}
        expect(response).to have_http_status(:unauthorized) # 401
      end
    end
=begin
    context 'with auth header' do
      let(:headers) do
        {
          'Authorization' => "Bearer #{user.api_keys.first.token}"
        }
      end

      it 'list bearer API keys' do
        get '/api-keys', headers: headers

        expect(response).to have_http_status(:no_content) # 204
      end
    end
=end
  end


  describe 'POST /api-keys' do
    let(:headers) { { 'Authorization' => "Basic #{encoded}" } }

    context 'with basic auth and bad user name' do
      let(:encoded) do
        Base64.encode64("#{user.email}-make-it-bad:#{user.password}")
      end

      it 'not authorized' do
        post '/api-keys', headers: headers
        expect(response).to have_http_status(:unauthorized) # 401
      end
    end

    context 'with basic auth and bad password' do
      let(:encoded) do
        Base64.encode64("#{user.email}:#{user.password}-make-it-bad")
      end

      it 'not authorized' do
        post '/api-keys', headers: headers
        expect(response).to have_http_status(:unauthorized) # 401
      end
    end

    context 'with basic auth and good credentials' do
      let(:encoded) do
        Base64.encode64("#{user.email}:#{user.password}")
      end

      it 'creates an ApiKey' do
        post '/api-keys', headers: headers
        expect(response.content_type).to eq('application/json; charset=utf-8')
        expect(response).to have_http_status(:created)
      end
    end
  end

=begin

  context 'DELETE /api-keys' do
    it 'creates an ApiKey' do
      post '/api-keys', headers: headers
      #post '/api-keys', params: { widget: {name: 'My Widget'} }, headers: headers

      expect(response.content_type).to eq('application/json; charset=utf-8')
      expect(response).to have_http_status(:created)
    end
  end
=end
end
