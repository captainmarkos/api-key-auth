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

Generate the seed data and then hop into the rails console.

```bash
bin/rails db:seed

bin/rails console
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


### Routes For API Key Authentication

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

Once again we use another method provided by Rails to handle the grunt-work of HTTP authentication.  The `authenticate_with_http_basic` will parse the `Authorization` header.  Unlike the token method variant caring about the `Bearer` scheme, the basic variant only cares about the `Basic` scheme.  Here's the doc [ActionController::HttpAuthentication::Basic::ControllerMethods](https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Basic/ControllerMethods.html).

A basic `Authorization` header will look something like:

```bash
Authorization: Basic foo@woohoo.com:topsecret
```

The email and password values will actually be base64 encoded and rails will automatically handle parsing and decoding these values.  You don't need Devise!

Let's create our first API key (using email / password from seed data):

```bash
curl -v -X POST http://localhost:3000/api-keys \
        -u foo@woohoo.com:topsecret
< HTTP/1.1 201 Created
{
  "id":5,
  "bearer_type": "User",
  "bearer_id":5,
  "token": "ac49cdacb9fc08330714f1fdfc9145e3",
  "created_at": "2022-07-10T23:19:56.627Z",
  "updated_at": "2022-07-10T23:19:56.627Z"
}
```

Looking in the rails console we now see two ApiKey records for this user (remember one was created via the seed data).

```ruby
[1] pry(main)> user = User.find_by(email: 'foo@woohoo.com')
=> #<User:0x00000001169c6708
 id: 5,
 email: "foo@woohoo.com",
 password_digest: "[FILTERED]",
 created_at: Sat, 09 Jul 2022 20:11:08.825997000 UTC +00:00,
 updated_at: Sat, 09 Jul 2022 20:11:08.825997000 UTC +00:00>

[2] pry(main)> user.api_keys
=> [#<ApiKey:0x0000000116b18368
  id: 2,
  bearer_type: "User",
  bearer_id: 5,
  token: "[FILTERED]",
  created_at: Sat, 09 Jul 2022 20:11:08.835937000 UTC +00:00,
  updated_at: Sat, 09 Jul 2022 20:11:08.835937000 UTC +00:00>,
 #<ApiKey:0x0000000116b30d78
  id: 5,
  bearer_type: "User",
  bearer_id: 5,
  token: "[FILTERED]",
  created_at: Sun, 10 Jul 2022 23:19:56.627854000 UTC +00:00,
  updated_at: Sun, 10 Jul 2022 23:19:56.627854000 UTC +00:00>]
```

Nice, but before we celebrate, let's make sure a bad password and bad emial are properly rejected with a 401 response.

```bash
curl -v -X POST http://localhost:3333/api-keys  -u bar@woohoo.com:topsecret
< HTTP/1.1 401 Unauthorized

curl -v -X POST http://localhost:3333/api-keys  -u foo@woohoo.com:bad_password
< HTTP/1.1 401 Unauthorized
```


### Listing API Keys

Next we'll work on the `#index` action.  Open up the `ApiKeysController` and let's list the API keys for the `current_bearer`.

```ruby
class ApiKeysController < ApplicationController
  include ApiKeyAuthenticatable

  ...

  def index
    render json: current_bearer.api_keys
  end

  ...
```

Smoke test with `curl` (use a valid token).

```bash
curl -v -X GET http://localhost:3333/api-keys -H 'Authorization: Bearer 8b0de4dc40339cd7745cf2128edb13c9'

< HTTP/1.1 200 OK
[
  {
    "id":2,
    "bearer_type": "User",
    "bearer_id":5,
    "token": "8b0de4dc40339cd7745cf2128edb13c9",
    "created_at": "2022-07-09T20:11:08.835Z",
    "updated_at": "2022-07-09T20:11:08.835Z"
  },
  {
    "id":5,
    "bearer_type": "User",
    "bearer_id":5,
    "token": "ac49cdacb9fc08330714f1fdfc9145e3",
    "created_at": "2022-07-10T23:19:56.627Z",
    "updated_at": "2022-07-10T23:19:56.627Z"
  }
]
```


### Revoking API Keys

To revoke an API key we need to update the `#destory` action of our controller.

```ruby
class ApiKeysController < ApplicationController
  include ApiKeyAuthenticatable

  ...

  def destroy
    current_api_key&.destroy
  end

  ...
```

That's all it takes.  Now let's test it out by revoking a API key with `curl`.  First let's find the key in the rails console.

```ruby
[1] pry(main)> User.last.api_keys.first.token
=> "9dc13ad94a52592aeb742cae3e8b620e"
```

Now revoke it with `curl`.

```bash
curl -v -X DELETE http://localhost:3000/api-keys \
        -H 'Authorization: Bearer 9dc13ad94a52592aeb742cae3e8b620e'
< HTTP/1.1 204 No Content
```

We got a `204 No Content` status but did it actually work?  Remember our `DELETE` endpoint has optional API key authentication, unlike the list endpoint which requires authentication, so even if an invalid API key was provided, ti would still return a `204 No Content` status.  This is probably not ideal but it works to exemplify the 2 different authentication actions.

Looking in the rails console we'll see that API key is deleted (and can also be seen by looking at the rails server output).

```bash
Started DELETE "/api-keys" for 127.0.0.1 at 2022-07-12 07:30:38 -0400
Processing by ApiKeysController#destroy as */*
   (0.1ms)  SELECT sqlite_version(*)
  ↳ app/controllers/concerns/api_key_authenticatable.rb:27:in `authenticator'
  ApiKey Load (0.7ms)  SELECT "api_keys".* FROM "api_keys" WHERE "api_keys"."token" = ? LIMIT ?  [["token", "[FILTERED]"], ["LIMIT", 1]]
  ↳ app/controllers/concerns/api_key_authenticatable.rb:27:in `authenticator'
  User Load (0.1ms)  SELECT "users".* FROM "users" WHERE "users"."id" = ? LIMIT ?  [["id", 10], ["LIMIT", 1]]
  ↳ app/controllers/concerns/api_key_authenticatable.rb:29:in `authenticator'
  TRANSACTION (0.0ms)  begin transaction
  ↳ app/controllers/api_keys_controller.rb:27:in `destroy'
  ApiKey Destroy (0.3ms)  DELETE FROM "api_keys" WHERE "api_keys"."id" = ?  [["id", 8]]
  ↳ app/controllers/api_keys_controller.rb:27:in `destroy'
  TRANSACTION (0.4ms)  commit transaction
  ↳ app/controllers/api_keys_controller.rb:27:in `destroy'
Completed 204 No Content in 22ms (ActiveRecord: 2.3ms | Allocations: 9671)
```

### Patching Vulnerabilities





### To Bear or not to Bear

Since our API keys are polymorphic, we can have multiple authenticatable models such as an `Admin` model or a `PacMan`.  The sky's the limit as long as the code is flexible enough and not expecting a `User` everywhere a bearer is.  There shouldn't be any issues making some obscure model an API key bearer.  Pair this with an authorization gem like `Pundit` and it'll work nicely.


### Wrap Up

We've implemented a login endpoint where we can generate new API keys, a logout endpoint where we can revoke existing API keys, as well as an endpoint allowing us to list the current user's API keys. From here, adding API key authentication to other controller actions is as simple as adding one of the 2 before_action callbacks.

Some people may raise concern that we're "rolling our own auth" here, but that's actually not true. We're using tools that Rails provides for us out-of-the-box. API key authentication doesn't have to be complex, and you most certainly don't have to use a third-party gem like Devise to implement it.


