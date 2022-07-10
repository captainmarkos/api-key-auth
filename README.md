### API Auth Key

Here's we implement API key authentication without using Devise.  When it comes to authentication, Ruby on Rails is a batteries-included framework.

Devise is over-kill for an API.



### Create App and Setup

```bash
rails new api-key-auth --api --database sqlite3 --skip-active-storage --skip-action-cable
```


#### Rename main Branch to master

First rename `main` to `master` in the local repo.

```bash
git branch -m main master
```

So far, so good! The local branch has been renamed - but we now need to make some changes on the remote repository.

```bash
git push -u origin master
```

We now have a new branch on the remote named `master`. Let's go on and remove the old `main` branch on the remote.

```bash
git push origin --delete main
```


#### Add Gems

```ruby
gem "bcrypt", "~> 3.1.7"

group :development, :test do
  ...
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'pry-theme'
  gem 'rubocop', require: false
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker', :git => 'https://github.com/faker-ruby/faker.git', :branch => 'master'
end

group :test do
  gem 'shoulda-matchers', '~> 5.0'
  gem 'simplecov', require: false
  gem 'database_cleaner-active_record', require: false
end
```


#### Turn off irb autocomplete in rails console

```bash
cat >> ~/.irbrc
IRB.conf[:USE_AUTOCOMPLETE] = false
```

The [pry-theme gem](https://github.com/kyrylo/pry-theme) adds some spice to the rails console.

```ruby
[1] pry(main)> pry-theme install vividchalk

[2] pry(main)> pry-theme try vividchalk

[3] pry(main)> pry-theme list
```

```bash
cat >> .pryrc
Pry.config.theme = 'vividchalk'
# Pry.config.theme = 'tomorrow-night'
# Pry.config.theme = 'pry-modern-256'
# Pry.config.theme = 'ocean'
```


### Create a User Model

Firstly, we'll need a user's table.  Pretty standard stuff.

```bash
bin/rails generate migration CreateUsers
```

Population with the following:

```ruby
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
  end
end
```

Apply the migration:

```bash
bin/rails db:migrate
```

Lastly, we'll create the actual `User` model:

```ruby
class User < ApplicationRecord
  has_secure_password
end
```

Rails has out-of-the-box support for user password authentication using the `has_secure_password` concern. Here's the doc for [ActiveModel::SecurePassword](https://api.rubyonrails.org/v7.0.3/classes/ActiveModel/SecurePassword/ClassMethods.html) and the [APIdoc](https://apidock.com/rails/v4.0.2/ActiveModel/SecurePassword/ClassMethods/has_secure_password).  You Don't Need Devise.


### Create an API Key Model

We need another model for `ApiKey`.

```bash
bin/rails generate migration CreateApiKeys
```

```ruby
class CreateApiKeys < ActiveRecord::Migration[7.0]
  def change
    create_table :api_keys do |t|
      t.references :bearer, polymorphic: true, index: true
      t.string :token, null: false

      t.timestamps
    end

    add_index :api_keys, :token, unique: true
  end
end
```

Note that we make this polymorphic.  In doing so we can have multiple `"bearers"`.

```bash
bin/rails db:migrate
```

Now we'll create the `ApiKey` model and add the API key association to the `User` model.

```ruby
class ApiKey < ApplicationRecord
  belongs_to :bearer, polymorphic: true
end
```

```ruby
class User < ApplicationRecord
  has_many :api_keys, as: :bearer

  ...
end
```


### Create Seed Data

To verify our work we'll make some seed data and drive from the rails console.

```ruby
# db/seeds.rb

emails = ['foo@woohoo.com', 'bar@yahoo.com', 'merp@flerp.com']

emails.each do |email|
  user = User.create!(email: email, password: 'topsecret')
  user.api_keys.create!(token: SecureRandom.hex)
end
```


```ruby
[1] pry(main)> User.first.authenticate('foo')
=> false

[2] pry(main)> User.first.authenticate('topsecret')
=> #<User:0x00000001235356c8
 id: 5,
 email: "foo@woohoo.com",
 password_digest: "$2a$12$SozPmTmi2L2dcPQxbPk2ZuqlEgWyf0R9CLAdhPeMXXtlyfPLjfv42",
 created_at: Sat, 09 Jul 2022 20:11:08.825997000 UTC +00:00,
 updated_at: Sat, 09 Jul 2022 20:11:08.825997000 UTC +00:00>


[3] pry(main)> User.first.api_keys
=> [#<ApiKey:0x00000001248c5e40
  id: 2,
  bearer_type: "User",
  bearer_id: 5,
  token: "8b0de4dc40339cd7745cf2128edb13c9",
  created_at: Sat, 09 Jul 2022 20:11:08.835937000 UTC +00:00,
  updated_at: Sat, 09 Jul 2022 20:11:08.835937000 UTC +00:00>]
```


#### Routes For API Key Authentication

Let's setup some routes:

- `GET /api-keys`: to list a bearer's API keys
- `POST /api-keys`: create a new API key - a standard 'login'
- `DELETE /api-keys`: to revoke the current API key - 'logout'

```ruby
Rails.application.routes.draw do
  ...

  # If we use `resources` then we would need to manage the ApiKey ids for
  # the destroy.  For simplicity we'll do the below but putting note here.
  # resources :api_keys, path: '/api-keys', only: [:index, :create, :destroy]

  get '/api-keys', to: 'api_keys#index'
  post '/api-keys', to: 'api_keys#create'
  delete '/api-keys', to: 'api_keys#destroy'
  ...
end
```


### Create an API Key Auth Concern

Create a typical Rails concern that allows controllers to require API key authentication `app/controllers/concerns/api_key_authenticatable.rb`.

```ruby
module ApiKeyAuthenticatable
  extend ActiveSupport::Concern

  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include ActionController::HttpAuthentication::Token::ControllerMethods
 
  attr_reader :current_api_key
  attr_reader :current_bearer
 
  # Use this to raise an error and automatically respond with
  # a 401 HTTP status code when API key authentication fails
  def authenticate_with_api_key!
    @current_bearer = authenticate_or_request_with_http_token &method(:authenticator)
  end
 
  # Use this for optional API key authentication
  def authenticate_with_api_key
    @current_bearer = authenticate_with_http_token &method(:authenticator)
  end
 
  private
 
  attr_writer :current_api_key
  attr_writer :current_bearer
 
  def authenticator(http_token, options)
    @current_api_key = ApiKey.find_by(token: http_token)
 
    current_api_key&.bearer
  end
end
```

Rails comes batteries-included.  By including a couple core classes we can take advantage of some useful methods:

- `#authenticate_or_request_with_http_token`: authenticate with an HTTP token, otherwise automatically request authentication - rails will respond with a `401 Unauthorized` HTTP status code.
- `#authenticate_with_http_token`: attempt to authenticate with an HTTP token, but don't raise an error if the token ends up being nil.

In both cases, we're going to be passing in our `#authenticator` method to handle the API key lookup. Rails will handle the rest. We'll be storing the current API key bearer and the current API key into controller-level instance variables, `current_bearer` and `current_api_key`, respectively.

See the docs for [ActionController::HttpAuthentication](https://api.rubyonrails.org/classes/ActionController/HttpAuthentication.html).

These methods will handle parsing of the `Authorization` HTTP header. There are multiple HTTP authorization schemes, but these 2 methods will only care about the `Bearer` scheme. We'll get into others.

An `Authorization` header for an API key will look something like this:

```bash
Authorization: Bearer 5c8e4327fd8b2bf3118f82b13890d89dc
```

This is how users will likely be interacting with the API.


### Controlling API Key Authentication

Let's define an empty controller so that we can start testing the API using `curl`.

```ruby
# app/controllers/api_keys_controller.rb

class ApiKeysController < ApplicationController
  def index
  end

  def create
  end

  def destroy
  end
end
```

Smoke test of endpoints with `curl`:

```bash
curl -v -X POST http://localhost:3000/api-keys
< HTTP/1.1 204 No Content

curl -v -X DELETE http://localhost:3000/api-keys
< HTTP/1.1 204 No Content

curl -v -X GET http://localhost:3000/api-keys
< HTTP/1.1 204 No Content
```

So far so good, no 404 or 5xx errors.  Now let's add our authenticatable concern to our controller.

```ruby
# app/controllers/api_keys_controller.rb

class ApiKeysController < ApplicationController
  include ApiKeyAutenticatable

  # Require token auth for index
  prepend_before_action :authenticate_with_api_key!, only: [:index]

  # Optional token auth for logout
  prepend_before_action :authenticate_with_api_key, only: [:destroy]

  ...
```

Run the smoke test again.

```bash
curl -v -X POST http://localhost:3000/api-keys
< HTTP/1.1 204 No Content

curl -v -X DELETE http://localhost:3000/api-keys
< HTTP/1.1 204 No Content

curl -v -X GET http://localhost:3000/api-keys
< HTTP/1.1 401 Unauthorized
```

Note our `GET` request now responds with a `401` HTTP status as intended.  Remember the `POST` doesn't require authentication and it's optional for the `DELETE` end-point.


### Create an API Key

```ruby
class ApiKeysController < ApplicationController
  include ApiKeyAuthenticatable

  ...

  def create
    authenticate_with_http_basic do |email, password|
      user = User.find_by email: email
      if user&.authenticate(password)
        api_key = user.api_keys.create! token: SecureRandom.hex
        render json: api_key, status: :created and return
      end
    end

    render status: :unauthorized
  end

  ...

end
```


