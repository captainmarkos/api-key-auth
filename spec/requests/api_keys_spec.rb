require 'rails_helper'

RSpec.describe 'ApiKeys', type: :request do

  describe 'GET /api-keys' do
    context 'with no auth header' do
      it 'not authorized' do
        get '/api-keys', headers: {}
        expect(response).to have_http_status(:unauthorized) # 401
      end
    end

    context 'with auth header' do
      let(:user) { create(:user, :with_api_keys) }
      let(:headers) do
        {
          'Authorization' => "Bearer #{user.api_keys.first.token}"
        }
      end

      it 'list bearer API keys' do
        get '/api-keys', headers: headers

        expect(response).to have_http_status(:no_content) # 204
binding.pry
      end
    end
  end

=begin
  context 'POST /api-keys' do
    it 'creates an ApiKey' do
      post '/api-keys', headers: headers
      #post '/api-keys', params: { widget: {name: 'My Widget'} }, headers: headers

      expect(response.content_type).to eq('application/json; charset=utf-8')
      expect(response).to have_http_status(:created)
    end
  end

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
