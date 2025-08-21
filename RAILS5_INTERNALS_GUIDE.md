# Ruby on Rails 5 Internals & Workflow Guide for AI Systems

## Table of Contents
1. [Rails Architecture Overview](#rails-architecture-overview)
2. [Request-Response Lifecycle](#request-response-lifecycle)
3. [Core Components Deep Dive](#core-components-deep-dive)
4. [MVC Pattern Implementation](#mvc-pattern-implementation)
5. [Database Layer & ActiveRecord](#database-layer--activerecord)
6. [Middleware Stack](#middleware-stack)
7. [Asset Pipeline](#asset-pipeline)
8. [Testing Framework](#testing-framework)
9. [Security Features](#security-features)
10. [Performance Optimization](#performance-optimization)
11. [Common Patterns & Anti-patterns](#common-patterns--anti-patterns)
12. [Debugging Strategies](#debugging-strategies)

## Rails Architecture Overview

### Core Philosophy
Rails follows "Convention over Configuration" (CoC) and "Don't Repeat Yourself" (DRY) principles. Understanding these helps predict Rails behavior:

- **Convention over Configuration**: Rails makes assumptions about what you want to do and how you're going to do it
- **DRY**: Every piece of knowledge must have a single, unambiguous, authoritative representation within a system

### Directory Structure & Purpose
```
app/
├── assets/          # CSS, JavaScript, images
├── channels/        # Action Cable channels (WebSockets)
├── controllers/     # Request handlers
├── helpers/         # View helpers
├── jobs/           # Background jobs (ActiveJob)
├── mailers/        # Email handlers
├── models/         # Business logic & data
└── views/          # Templates (ERB, HAML, etc.)

config/
├── application.rb   # Main app configuration
├── database.yml     # Database settings
├── routes.rb       # URL routing rules
├── environments/   # Environment-specific settings
│   ├── development.rb
│   ├── production.rb
│   └── test.rb
├── initializers/   # Run on app boot
└── locales/        # i18n translations

db/
├── migrate/        # Database migrations
├── schema.rb       # Current DB structure
└── seeds.rb        # Initial data

lib/
├── assets/         # Custom assets
└── tasks/          # Rake tasks

public/             # Static files served directly
test/ or spec/      # Test files
vendor/             # Third-party code
Gemfile            # Dependencies declaration
```

## Request-Response Lifecycle

### Complete Flow (Step-by-Step)

1. **Web Server Reception**
   - Request arrives at web server (Puma, Unicorn, etc.)
   - Server passes to Rack interface

2. **Rack Processing**
   ```ruby
   # Rack provides common interface between web servers and Ruby frameworks
   # Rails.application is a Rack application
   ```

3. **Middleware Stack Execution**
   ```ruby
   # View with: rails middleware
   # Common middleware in order:
   Rack::Sendfile
   ActionDispatch::Static
   ActionDispatch::Executor
   ActiveSupport::Cache::Strategy::LocalCache::Middleware
   Rack::Runtime
   ActionDispatch::RequestId
   Rails::Rack::Logger
   ActionDispatch::ShowExceptions
   ActionDispatch::DebugExceptions
   ActionDispatch::RemoteIp
   ActionDispatch::Reloader
   ActionDispatch::Callbacks
   ActiveRecord::Migration::CheckPending
   ActionDispatch::Cookies
   ActionDispatch::Session::CookieStore
   ActionDispatch::Flash
   Rack::Head
   Rack::ConditionalGet
   Rack::ETag
   ```

4. **Router Processing**
   ```ruby
   # config/routes.rb defines URL patterns
   Rails.application.routes.draw do
     get '/users/:id', to: 'users#show'
     # Creates params[:id] available in controller
   end
   ```

5. **Controller Instantiation**
   ```ruby
   # Rails creates new controller instance per request
   # Before filters run first
   before_action :authenticate_user!
   before_action :set_user, only: [:show, :edit, :update]
   ```

6. **Action Execution**
   ```ruby
   def show
     # Action logic here
     # Instance variables available to views
     @user = User.find(params[:id])
   end
   ```

7. **View Rendering**
   ```ruby
   # Implicit rendering: looks for app/views/users/show.html.erb
   # Explicit: render :show, render json: @user
   ```

8. **Response Return**
   - After filters execute
   - Response sent back through middleware
   - Final response to client

## Core Components Deep Dive

### ActiveRecord (ORM Layer)

#### Connection Management
```ruby
# Database connection pool configuration
# config/database.yml
production:
  adapter: mysql2
  pool: 25  # Maximum connections
  timeout: 5000
  reaping_frequency: 10  # Seconds between reaping dead connections
```

#### Query Interface Chain
```ruby
# Lazy loading - queries execute only when needed
User.where(active: true)  # Returns ActiveRecord::Relation
    .includes(:posts)      # Eager loading to prevent N+1
    .order(created_at: :desc)
    .limit(10)
    .offset(20)           # SQL not executed yet
    .to_a                 # NOW SQL executes

# Query methods that trigger immediate execution:
# .first, .last, .find, .find_by, .count, .sum, .average, .minimum, .maximum
```

#### Callbacks Execution Order
```ruby
# CREATE operation callbacks order:
before_validation
after_validation
before_save
around_save
before_create
around_create
after_create
after_save
after_commit/after_rollback

# UPDATE operation callbacks order:
before_validation
after_validation
before_save
around_save
before_update
around_update
after_update
after_save
after_commit/after_rollback

# DESTROY operation callbacks order:
before_destroy
around_destroy
after_destroy
after_commit/after_rollback
```

#### Associations & Loading Strategies
```ruby
class User < ApplicationRecord
  has_many :posts
  has_many :comments, through: :posts
  has_one :profile
  belongs_to :company, optional: true  # Rails 5 requires belongs_to by default
  
  # Scopes for reusable queries
  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Counter cache for performance
  has_many :posts, counter_cache: true
end

# Eager loading strategies:
User.includes(:posts)  # LEFT OUTER JOIN, separate queries
User.eager_load(:posts)  # LEFT OUTER JOIN, single query
User.preload(:posts)  # Multiple queries, no JOIN
User.joins(:posts)  # INNER JOIN, doesn't load associations
```

### ActionController

#### Request Object Details
```ruby
class UsersController < ApplicationController
  def create
    # Request object provides:
    request.method          # GET, POST, PUT, DELETE, etc.
    request.headers         # HTTP headers hash
    request.body           # Raw request body
    request.remote_ip      # Client IP
    request.xhr?           # AJAX request?
    request.format         # :html, :json, :xml
    request.ssl?           # HTTPS?
    request.local?         # Local request?
    request.path           # /users/new
    request.fullpath       # /users/new?sort=name
    request.original_url   # http://example.com/users/new?sort=name
    
    # Params object:
    params                 # ActionController::Parameters
    params.require(:user).permit(:name, :email)  # Strong parameters
  end
end
```

#### Response Handling
```ruby
class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])
    
    respond_to do |format|
      format.html  # Renders show.html.erb
      format.json { render json: @post }
      format.xml  { render xml: @post }
      format.js   # Renders show.js.erb for AJAX
    end
    
    # Response methods:
    head :ok                    # Empty response with status
    redirect_to posts_path      # 302 redirect
    redirect_to @post, status: :moved_permanently  # 301 redirect
    render status: :not_found   # 404 with template
    render plain: "Text"        # Plain text response
    render json: { key: 'value' }
    render xml: @post.to_xml
    send_file '/path/to/file'   # File download
    send_data pdf_content, filename: 'report.pdf'
  end
end
```

### ActionView

#### Template Resolution Process
```ruby
# Rails looks for templates in this order:
# 1. app/views/controller_name/action_name.format.handler
# 2. app/views/application/action_name.format.handler
# 3. Inheritance chain views

# Example for PostsController#show with format.html:
# 1. app/views/posts/show.html.erb
# 2. app/views/posts/show.html.haml
# 3. app/views/posts/show.html.slim
# 4. app/views/application/show.html.erb (if exists)
```

#### Helper Methods & Form Builders
```ruby
# View helpers available globally
link_to "Profile", user_path(@user), class: "btn"
image_tag "logo.png", alt: "Logo"
content_tag :div, "Content", class: "wrapper"
truncate @post.body, length: 100
pluralize @users.count, "user"
number_to_currency @product.price
time_ago_in_words @post.created_at

# Form builders
<%= form_with model: @user, local: true do |form| %>
  <%= form.text_field :name %>
  <%= form.email_field :email %>
  <%= form.collection_select :role_id, Role.all, :id, :name %>
  <%= form.fields_for :profile do |profile_form| %>
    <%= profile_form.text_field :bio %>
  <% end %>
<% end %>
```

## Database Layer & ActiveRecord

### Migration Mechanics
```ruby
class CreateUsers < ActiveRecord::Migration[5.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.integer :age
      t.decimal :balance, precision: 10, scale: 2
      t.boolean :active, default: true
      t.text :bio
      t.json :preferences  # MySQL 5.7+ / PostgreSQL
      t.references :company, foreign_key: true
      t.timestamps  # created_at, updated_at
    end
    
    add_index :users, :email, unique: true
    add_index :users, [:company_id, :active]  # Composite index
  end
end

# Rollback-safe migrations
def up
  add_column :users, :status, :string
end

def down
  remove_column :users, :status
end
```

### Transaction Management
```ruby
# Transactions ensure data consistency
ActiveRecord::Base.transaction do
  user = User.create!(name: "John")
  profile = user.create_profile!(bio: "Developer")
  # If any operation fails, entire transaction rolls back
end

# Nested transactions (savepoints)
User.transaction do
  User.create!(name: "Parent")
  
  User.transaction(requires_new: true) do
    User.create!(name: "Child")
    raise ActiveRecord::Rollback  # Only rolls back inner transaction
  end
end

# Locking strategies
user = User.lock.find(1)  # SELECT ... FOR UPDATE (pessimistic)
user = User.find(1)
user.with_lock do  # Locks during block execution
  user.update!(balance: user.balance + 100)
end
```

### Database-Specific Features
```ruby
# MySQL specific
class User < ApplicationRecord
  # Full-text search (MySQL)
  scope :search, ->(term) { where("MATCH(name, bio) AGAINST (?)", term) }
end

# PostgreSQL specific
class Product < ApplicationRecord
  # JSONB queries (PostgreSQL)
  scope :with_feature, ->(feature) { 
    where("features @> ?", { feature => true }.to_json) 
  }
  
  # Array columns (PostgreSQL)
  scope :with_tag, ->(tag) { where(":tag = ANY(tags)", tag: tag) }
end
```

## Middleware Stack

### Custom Middleware Creation
```ruby
# lib/middleware/request_timer.rb
class RequestTimer
  def initialize(app)
    @app = app
  end
  
  def call(env)
    start_time = Time.current
    status, headers, response = @app.call(env)  # Pass to next middleware
    duration = Time.current - start_time
    headers['X-Runtime'] = duration.to_s
    [status, headers, response]
  end
end

# config/application.rb
config.middleware.use RequestTimer
config.middleware.insert_before ActionDispatch::Static, RequestTimer
config.middleware.insert_after Rack::Sendfile, RequestTimer
config.middleware.delete ActionDispatch::Static  # Remove middleware
```

## Asset Pipeline

### Sprockets Processing Chain
```ruby
# app/assets/javascripts/application.js
//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require_tree .  # Include all files in directory
//= require_self   # Include this file's content

# app/assets/stylesheets/application.scss
/*
 *= require_self
 *= require_tree .
 */
@import "bootstrap";  # Using Sass @import

# Fingerprinting in production
# application-908e25f4bf641868d8683022a5b62f54.js
```

### Asset Helpers
```ruby
# In views
<%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
<%= javascript_include_tag 'application', 'data-turbolinks-track': 'reload' %>
<%= image_tag 'logo.png', class: 'logo' %>
<%= asset_path 'application.js' %>  # Returns path with fingerprint

# In SCSS
.logo {
  background-image: image-url('logo.png');  // Handles fingerprinting
}
```

## Testing Framework

### Test Types & Execution Order
```ruby
# test/test_helper.rb or spec/rails_helper.rb
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup fixtures
  fixtures :all
  
  # Transactional tests (automatic rollback)
  self.use_transactional_tests = true
end

# Model test
class UserTest < ActiveSupport::TestCase
  test "should not save user without email" do
    user = User.new
    assert_not user.save
    assert_includes user.errors[:email], "can't be blank"
  end
end

# Controller test
class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)  # Fixture
  end
  
  test "should get show" do
    get user_url(@user)
    assert_response :success
    assert_select 'h1', @user.name
  end
end

# Integration test
class UserFlowsTest < ActionDispatch::IntegrationTest
  test "login and browse site" do
    get "/login"
    assert_response :success
    
    post "/login", params: { email: 'user@example.com', password: 'secret' }
    follow_redirect!
    assert_response :success
    assert_select 'h1', 'Dashboard'
  end
end
```

## Security Features

### Built-in Protections
```ruby
# CSRF Protection (enabled by default)
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception  # Rails 5 default
  # Alternatives:
  # protect_from_forgery with: :null_session  # API controllers
  # protect_from_forgery with: :reset_session
  
  # Skip for specific actions
  skip_before_action :verify_authenticity_token, only: [:webhook]
end

# Strong Parameters
def user_params
  params.require(:user).permit(:name, :email, roles: [], 
    profile_attributes: [:bio, :avatar])
end

# SQL Injection Prevention
# GOOD - Parameterized queries
User.where("name = ?", params[:name])
User.where(name: params[:name])

# BAD - Direct interpolation
User.where("name = '#{params[:name]}'")  # VULNERABLE!

# XSS Prevention
# Views automatically escape output
<%= @user.bio %>  # HTML escaped
<%== @user.bio %> # Raw output (dangerous)
<%= raw @user.bio %> # Raw output (dangerous)
<%= @user.bio.html_safe %> # Marked as safe (use carefully)

# Content Security Policy (Rails 5.2+)
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data
  policy.object_src  :none
  policy.script_src  :self, :https
  policy.style_src   :self, :https
end
```

## Performance Optimization

### Query Optimization
```ruby
# N+1 Query Problem & Solutions
# BAD - N+1 queries
@posts = Post.all
@posts.each do |post|
  puts post.user.name  # Query for each post's user
end

# GOOD - Eager loading
@posts = Post.includes(:user)  # 2 queries total
@posts = Post.includes(:user, comments: :author)  # Nested eager loading

# Query Caching (within request)
User.find(1)  # Database query
User.find(1)  # Cached, no query

# Low-level caching
Rails.cache.fetch("user_#{id}", expires_in: 12.hours) do
  User.find(id)
end

# Russian Doll Caching in views
<% cache @post do %>
  <%= @post.title %>
  <% cache @post.author do %>
    <%= @post.author.name %>
  <% end %>
<% end %>
```

### Database Indexes
```ruby
# Check missing indexes
# In Rails console
ActiveRecord::Base.connection.tables.each do |table|
  indexes = ActiveRecord::Base.connection.indexes(table)
  columns = ActiveRecord::Base.connection.columns(table)
  
  # Find foreign keys without indexes
  columns.select { |c| c.name.ends_with?('_id') }.each do |column|
    unless indexes.any? { |i| i.columns.include?(column.name) }
      puts "Missing index on #{table}.#{column.name}"
    end
  end
end
```

## Common Patterns & Anti-patterns

### Good Patterns
```ruby
# Service Objects
class UserRegistrationService
  def initialize(user_params)
    @user_params = user_params
  end
  
  def call
    user = User.new(@user_params)
    if user.save
      UserMailer.welcome(user).deliver_later
      CreateDefaultSettings.new(user).call
      Result.new(success: true, user: user)
    else
      Result.new(success: false, errors: user.errors)
    end
  end
end

# Query Objects
class RecentActiveUsersQuery
  def initialize(relation = User.all)
    @relation = relation
  end
  
  def call(days_ago: 7)
    @relation
      .where(active: true)
      .where('last_login_at > ?', days_ago.days.ago)
      .order(last_login_at: :desc)
  end
end

# Form Objects
class RegistrationForm
  include ActiveModel::Model
  
  attr_accessor :email, :password, :terms_accepted
  
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }
  validates :terms_accepted, acceptance: true
  
  def save
    return false unless valid?
    
    User.create!(email: email, password: password)
  end
end

# Concerns for shared behavior
module Trackable
  extend ActiveSupport::Concern
  
  included do
    after_create :track_creation
    after_update :track_update
  end
  
  def track_creation
    ActivityLog.create!(action: 'created', trackable: self)
  end
  
  def track_update
    ActivityLog.create!(action: 'updated', trackable: self)
  end
end
```

### Anti-patterns to Avoid
```ruby
# FAT Controllers - BAD
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    if @user.save
      UserMailer.welcome(@user).deliver_later
      @user.profile.create!(bio: 'New user')
      TeamNotifier.new_member(@user.team, @user)
      Analytics.track('user_registered', user_id: @user.id)
      redirect_to @user
    else
      render :new
    end
  end
end

# BETTER - Thin controller with service
class UsersController < ApplicationController
  def create
    result = UserRegistrationService.new(user_params).call
    if result.success?
      redirect_to result.user
    else
      @user = User.new(user_params)
      @user.errors = result.errors
      render :new
    end
  end
end

# FAT Models - BAD
class User < ApplicationRecord
  # Too many responsibilities
  def send_welcome_email
    UserMailer.welcome(self).deliver_later
  end
  
  def export_to_csv
    CSV.generate do |csv|
      # ...
    end
  end
  
  def calculate_subscription_price
    # Complex pricing logic
  end
end

# BETTER - Single Responsibility
class User < ApplicationRecord
  # Only data and simple business logic
end

class UserExporter
  def to_csv(users)
    # CSV logic
  end
end

class SubscriptionPricer
  def calculate(user)
    # Pricing logic
  end
end
```

## Debugging Strategies

### Rails Console Techniques
```ruby
# Reload console without restarting
reload!

# Sandbox mode (rollback on exit)
rails console --sandbox

# View SQL for queries
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Inspect object without all attributes
user = User.first
user.attributes.slice('id', 'email', 'name')

# Get all methods specific to model
User.instance_methods(false)

# View source location
User.instance_method(:some_method).source_location

# Benchmark queries
Benchmark.ms { User.all.to_a }

# Explain query plan
User.where(active: true).explain
```

### Debugging Tools
```ruby
# Better Errors gem - development
# Provides interactive console in browser on errors

# Byebug gem
def some_method
  byebug  # Breakpoint
  # Interactive debugger starts here
end

# Rails.logger
Rails.logger.debug "Variable value: #{@variable.inspect}"
Rails.logger.info "Processing user #{user.id}"
Rails.logger.error "Failed to process: #{e.message}"

# Custom log tags
Rails.logger.tagged('USER_IMPORT') do
  Rails.logger.info "Starting import"
  # All logs within block are tagged
end

# View routing information
Rails.application.routes.url_helpers.users_path
rake routes | grep user
rails routes -c UsersController
```

### Performance Debugging
```ruby
# Bullet gem - detects N+1 queries
# rack-mini-profiler - shows page load breakdown

# Manual profiling
class ApplicationController < ActionController::Base
  around_action :profile_request
  
  def profile_request
    result = nil
    time = Benchmark.ms { result = yield }
    Rails.logger.info "#{controller_name}##{action_name} took #{time}ms"
    result
  end
end

# Memory profiling
require 'memory_profiler'
report = MemoryProfiler.report do
  # Code to profile
end
report.pretty_print

# SQL query analysis
ActiveRecord::Base.connection.execute("EXPLAIN ANALYZE SELECT * FROM users")
```

## Rails 5 Specific Features

### API Mode
```ruby
# Generate API-only application
# rails new my_api --api

class ApplicationController < ActionController::API
  # Lighter controller without view rendering
  # No sessions, cookies, flash, assets
end
```

### ActionCable (WebSockets)
```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end
  
  def receive(data)
    ActionCable.server.broadcast("chat_#{params[:room]}", data)
  end
end

# Broadcasting from anywhere
ActionCable.server.broadcast("chat_general", { message: "Hello" })
```

### ActiveRecord Attributes API
```ruby
class Product < ApplicationRecord
  attribute :price_in_cents, :integer
  attribute :published_at, :datetime, default: -> { Time.current }
  
  # Custom type
  attribute :preferences, PreferencesType.new
end
```

### ApplicationRecord Base Class
```ruby
# All models inherit from ApplicationRecord instead of ActiveRecord::Base
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  
  # Global model configurations
  def self.sanitize_sql_like(string, escape_character = "\\")
    pattern = Regexp.union(escape_character, "%", "_")
    string.gsub(pattern) { |x| [escape_character, x].join }
  end
end
```

## Working with Rails 5 Projects - AI Guidelines

### Code Analysis Approach
1. Always check `Gemfile` for dependencies and versions
2. Review `config/routes.rb` to understand application structure
3. Check `db/schema.rb` for database structure
4. Look for service objects in `app/services/`
5. Check for concerns in `app/models/concerns/` and `app/controllers/concerns/`
6. Review tests to understand expected behavior

### Common Rails 5 Gotchas
1. `belongs_to` is required by default (use `optional: true` to make optional)
2. `form_with` generates remote forms by default (use `local: true` for regular forms)
3. Parameters must be permitted (strong parameters)
4. CSRF protection is enabled by default
5. Migrations use versioned format `ActiveRecord::Migration[5.0]`

### Performance Considerations
1. Always use eager loading for associations in loops
2. Add database indexes for foreign keys and frequently queried columns
3. Use counter caches for association counts
4. Implement fragment caching for expensive view partials
5. Use background jobs for time-consuming operations

### Security Checklist
1. Always use parameterized queries
2. Sanitize user input before display
3. Use strong parameters in controllers
4. Keep CSRF protection enabled
5. Validate data at model level
6. Use `secrets.yml` or credentials for sensitive data
7. Implement proper authentication and authorization

### Testing Best Practices
1. Test model validations and associations
2. Test controller actions with different parameters
3. Write integration tests for critical user flows
4. Use fixtures or factories for test data
5. Keep tests isolated and independent
6. Run tests before committing code

## Quick Reference Commands

```bash
# Generate commands
rails generate model User name:string email:string
rails generate controller Users index show
rails generate migration AddAgeToUsers age:integer
rails generate scaffold Post title:string body:text

# Database commands
rails db:create
rails db:migrate
rails db:rollback
rails db:seed
rails db:reset  # drop, create, migrate, seed

# Console commands
rails console
rails console --sandbox
rails dbconsole

# Server commands
rails server
rails server -p 3001  # Different port
rails server -b 0.0.0.0  # Bind to all interfaces

# Routes
rails routes
rails routes -g user  # Grep for 'user'
rails routes -c UsersController

# Tasks
rails -T  # List all tasks
rails stats  # Code statistics
rails notes  # Show TODO, FIXME comments
rails about  # Environment info

# Testing
rails test
rails test test/models
rails test test/models/user_test.rb
rails test test/models/user_test.rb:15  # Specific line

# Assets
rails assets:precompile
rails assets:clean
rails assets:clobber
```

## Conclusion

This guide provides comprehensive understanding of Rails 5 internals necessary for AI systems to effectively work with Rails applications. Remember that Rails emphasizes convention over configuration - when in doubt, follow Rails conventions and the patterns already established in the codebase.

Key principles for AI working with Rails:
1. Respect existing patterns in the codebase
2. Follow Rails conventions unless explicitly overridden
3. Consider performance implications of database queries
4. Maintain security best practices
5. Write tests for new functionality
6. Keep controllers thin and models focused
7. Use service objects for complex business logic
8. Document non-obvious code decisions

Always verify assumptions by checking the actual codebase structure and running tests before making significant changes.