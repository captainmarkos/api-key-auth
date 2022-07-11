require 'rails_helper'

RSpec.describe 'ApiKeys', type: :request do
  let(:user) { create(:user, :with_api_keys) }
  let(:headers) { { 'Authorization' => "#{auth_scheme}" } }

  describe 'GET /api-keys' do
    context 'with bearer authentication' do
      context 'when missing token' do
        let(:auth_scheme) { 'Bearer' }

        it 'not authorized' do
          get '/api-keys', headers: headers
          expect(response).to have_http_status(:unauthorized) # 401
        end
      end

      context 'with valid token' do
        let(:auth_scheme) { "Bearer #{user.api_keys.first.token}" }

        it 'list bearer API keys' do
          get '/api-keys', headers: headers
          expect(response).to have_http_status(:no_content) # 204
        end
      end
    end
  end

  describe 'POST /api-keys' do
    context 'with basic authentication' do
      let(:auth_scheme) { "Basic #{encoded}" }

      context 'when bad user name' do
        let(:encoded) { Base64.encode64("#{user.email}-fail:#{user.password}") }

        it 'not authorized' do
          post '/api-keys', headers: headers
          expect(response).to have_http_status(:unauthorized) # 401
        end
      end

      context 'when bad password' do
        let(:encoded) { Base64.encode64("#{user.email}:#{user.password}-fail") }

        it 'not authorized' do
          post '/api-keys', headers: headers
          expect(response).to have_http_status(:unauthorized) # 401
        end
      end

      context 'when good credentials' do
        let(:encoded) { Base64.encode64("#{user.email}:#{user.password}") }

        it 'creates an ApiKey' do
          post '/api-keys', headers: headers
          expect(response.content_type).to eq('application/json; charset=utf-8')
          expect(response).to have_http_status(:created)
        end
      end
    end
  end
=begin

  describe 'DELETE /api-keys' do
    context '' do
      let(:auth_scheme) { "Basic #{encoded}" }

      context '' do
        it 'destroys an ApiKey' do
          post '/api-keys', headers: headers
          #post '/api-keys', params: { api_key: {id: 1} }, headers: headers

          expect(response.content_type).to eq('application/json; charset=utf-8')
          expect(response).to have_http_status(:created)
        end
      end
    end
  end

=end
end
