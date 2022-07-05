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

#### Create an API Key Model


