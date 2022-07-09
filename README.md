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


#### Create a user model

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


#### Create an API Key Model

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


#### Create Seed Data

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
