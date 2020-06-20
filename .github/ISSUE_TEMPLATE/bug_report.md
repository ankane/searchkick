---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug report
assignees: ''

---

**First**
Search existing issues to see if it’s been reported.

**Describe the bug**
A clear and concise description of the bug.

**To Reproduce**
Use this code to reproduce when possible:

```ruby
require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "activerecord", require: "active_record"
  gem "activejob", require: "active_job"
  gem "sqlite3"
  gem "searchkick", git: "https://github.com/ankane/searchkick.git"
end

puts "Searchkick version: #{Searchkick::VERSION}"
puts "Elasticsearch version: #{Searchkick.server_version}"

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
ActiveJob::Base.queue_adapter = :inline

ActiveRecord::Migration.create_table :products do |t|
  t.string :name
end

class Product < ActiveRecord::Base
  searchkick
end

Product.reindex
Product.create!(name: "Test")
Product.search_index.refresh
p Product.search("test", fields: [:name]).response
```

**Expected behavior**
A clear and concise description of what you expected to happen.

**Additional context**
Add any other context about the problem here.
