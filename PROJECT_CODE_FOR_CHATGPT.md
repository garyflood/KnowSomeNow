# KnowSomeNow – Full project code (for ChatGPT)

Rails 8 app: AI-powered device instructions. Users add devices, get step-by-step instructions via LLM. Images from Wikipedia/Cloudinary. Devise auth.

---

## Gemfile

```ruby
source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[windows jruby]
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"
gem "sprockets-rails"
gem "bootstrap", "~> 5.3"
gem "autoprefixer-rails"
gem "font-awesome-sass", "~> 6.1"
gem "simple_form", github: "heartcombo/simple_form"
gem "sassc-rails"
gem 'devise'
gem "ruby_llm", "~> 1.2.0"
gem 'redcarpet'
gem 'cloudinary'

group :development, :test do
  gem "dotenv-rails"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
```

---

## config/routes.rb

```ruby
Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  resources :users, only: [:show]
  resources :devices, only: [:create, :show, :destroy]
  resources :devices do
    resources :instructions, only: [:create, :update]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

---

## config/application.rb

```ruby
require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module KnowSomeNow
  class Application < Rails::Application
    config.generators do |generate|
      generate.assets false
      generate.helper false
      generate.test_framework :test_unit, fixture: false
    end
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
  end
end
```

---

## config/initializers/ruby_llm.rb

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.openai_api_base = "https://models.inference.ai.azure.com"
end
```

---

## config/initializers/cloudinary.rb

```ruby
Cloudinary.config do |config|
  config.cloud_name = ENV['CLOUDINARY_CLOUD_NAME']
  config.api_key = ENV['CLOUDINARY_API_KEY']
  config.api_secret = ENV['CLOUDINARY_API_SECRET']
  config.secure = true
end
```

---

## config/database.yml

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: know_some_now_development

test:
  <<: *default
  database: know_some_now_test

production:
  primary: &primary_production
    <<: *default
    database: know_some_now_production
    username: know_some_now
    password: <%= ENV["KNOW_SOME_NOW_DATABASE_PASSWORD"] %>
  cache:
    <<: *primary_production
    database: know_some_now_production_cache
    migrations_paths: db/cache_migrate
  queue:
    <<: *primary_production
    database: know_some_now_production_queue
    migrations_paths: db/queue_migrate
  cable:
    <<: *primary_production
    database: know_some_now_production_cable
    migrations_paths: db/cable_migrate
```

---

## db/schema.rb

```ruby
ActiveRecord::Schema[8.1].define(version: 2026_03_05_144147) do
  enable_extension "pg_catalog.plpgsql"

  create_table "devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "image"
    t.string "module"
    t.string "name"
    t.text "system_prompt"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  create_table "instructions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "device_id", null: false
    t.text "steps"
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_instructions_on_device_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "devices", "users"
  add_foreign_key "instructions", "devices"
end
```

---

## app/controllers/application_controller.rb

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :authenticate_user!
  stale_when_importmap_changes

  def after_sign_up_path_for(resource)
    user_path(resource)
  end

  def after_sign_in_path_for(resource)
    user_path(resource)
  end
end
```

---

## app/controllers/devices_controller.rb

```ruby
class DevicesController < ApplicationController
  # rubocop:disable Metrics/MethodLength
  def create
    @device = Device.new(device_params)
    @device.user = current_user

    begin
      chat = RubyLLM.chat
      system_prompt = "You are an expert in using devices.
    Give me step by step instructions to use a device.
    Answer concisely in Markdown"

      chat.with_instructions(system_prompt)
      response = chat.ask("How do I use a #{@device.name}?")

      @api_response = response.content
    rescue StandardError => e
      @api_response = "Unable to generate instructions at this time. Error: #{e.message}"
    end

    # Fetch a relevant device image from Wikipedia and store it via Cloudinary
    @device.image = generate_and_upload_image(@device.name)

    if @device.save
      instruction = @device.build_instruction(steps: @api_response)

      if instruction.save
        flash[:notice] = 'Device was successfully added with instructions!'
      else
        flash[:alert] = 'Device saved but there was a problem saving the instructions.'
      end

      redirect_to user_path(@device.user)
    else
      @user = @device.user
      flash.now[:alert] = 'There was a problem adding the device.'
      render 'users/show'
    end
  end
  # rubocop:enable Metrics/MethodLength

  def destroy
    @device = Device.find(params[:id])

    if @device.destroy
      flash[:notice] = "Device was successfully deleted."
    else
      flash[:alert] = "There was a problem deleting the device."
    end

    redirect_to user_path(current_user)
  end

  def show
    @device = Device.find(params[:id])
  end

  private

  # Searches Wikipedia for the device, uploads the found image to Cloudinary,
  # and returns the permanent Cloudinary URL. Returns nil if no image is found.
  def generate_and_upload_image(device_name)
    photo_url = fetch_wikipedia_image_url(device_name)
    return nil if photo_url.nil?

    result = Cloudinary::Uploader.upload(photo_url, folder: "knowsomenow/devices")
    result["secure_url"]
  rescue StandardError => e
    Rails.logger.error("Image fetch/upload failed: #{e.message}")
    nil
  end

  def fetch_wikipedia_image_url(device_name)
    title = search_wikipedia_title(device_name)
    return nil if title.nil?

    encoded_title = URI.encode_uri_component(title)
    uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded_title}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "KnowSomeNow/1.0 (device-instructions-app)"
    JSON.parse(http.request(request).body).dig("thumbnail", "source")
  end

  def search_wikipedia_title(device_name)
    encoded_query = URI.encode_uri_component(device_name)
    uri = URI("https://en.wikipedia.org/w/api.php?action=opensearch&search=#{encoded_query}&limit=1&format=json")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "KnowSomeNow/1.0 (device-instructions-app)"
    results = JSON.parse(http.request(request).body)
    results[1]&.first
  end

  def device_params
    params.require(:device).permit(:name)
  end
end
```

---

## app/controllers/instructions_controller.rb

```ruby
class InstructionsController < ApplicationController
  before_action :set_device, only: %i[create update]
  before_action :set_instruction, only: [:update]

  def create
    @instruction = @device.build_instruction(instruction_params)
    if @instruction.save
      redirect_to user_path(@device.user), notice: 'Instruction was successfully created.'
    else
      redirect_to user_path(@device.user), alert: 'There was a problem creating the instruction.'
    end
  end

  def update
    begin
      chat = RubyLLM.chat
      system_prompt = <<~PROMPT
        You are an expert in using devices.
        Given the old instructions, clarify or improve only the part related to the user's message.
        Return the full instructions, with the clarified part updated and all other steps unchanged.
        Answer concisely in Markdown.
      PROMPT

      chat.with_instructions(system_prompt)
      chat.add_message(role: "system", content: "Old instructions: #{@instruction.steps}")
      response = chat.ask(instruction_params[:steps])
      @instruction.steps = response.content
    rescue StandardError => e
      flash[:alert] = "Unable to update instructions at this time. Error: #{e.message}"
      redirect_to device_path(@device) and return
    end

    if @instruction.save
      redirect_to device_path(@device), notice: 'Instruction was successfully updated.'
    else
      redirect_to device_path(@device), alert: 'There was a problem updating the instruction.'
    end
  end

  private

  def set_device
    @device = Device.find(params[:device_id])
  end

  def set_instruction
    @instruction = @device.instruction
  end

  def instruction_params
    params.require(:instruction).permit(:steps)
  end
end
```

---

## app/controllers/pages_controller.rb

```ruby
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]
  def home
    return unless user_signed_in?

    redirect_to user_path(current_user)
  end
end
```

---

## app/controllers/users_controller.rb

```ruby
class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @device = Device.new
    @devices = @user.devices.includes(:instruction)
  end
end
```

---

## app/models/application_record.rb

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
```

---

## app/models/device.rb

```ruby
class Device < ApplicationRecord
  belongs_to :user
  has_one :instruction, dependent: :destroy
end
```

---

## app/models/instruction.rb

```ruby
class Instruction < ApplicationRecord
  belongs_to :device
end
```

---

## app/models/user.rb

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :devices, dependent: :destroy
end
```

---

## app/helpers/application_helper.rb

```ruby
module ApplicationHelper
  def markdown(text)
    return "" if text.blank?

    options = { filter_html: true, hard_wrap: true, link_attributes: { rel: "nofollow", target: "_blank" } }
    extensions = { autolink: true, superscript: true, fenced_code_blocks: true }
    renderer = Redcarpet::Render::HTML.new(options)
    Redcarpet::Markdown.new(renderer, extensions).render(text).html_safe
  end
end
```

---

## app/helpers/markdown_helper.rb

```ruby
module MarkdownHelper
  def markdown(text)
    options = {
      hard_wrap: true,
      filter_html: true,
      autolink: true,
      no_intra_emphasis: true
    }
    extensions = {
      fenced_code_blocks: true,
      tables: true
    }
    renderer = Redcarpet::Render::HTML.new(options)
    markdown = Redcarpet::Markdown.new(renderer, extensions)
    markdown.render(text).html_safe
  end
end
```

---

## app/views/layouts/application.html.erb

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "Know Some Now" %></title>
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="Know Some Now">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= yield :head %>
    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0" />
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body>
  <%= render "layouts/navbar" %>
    <%= yield %>
  </body>
</html>
```

---

## app/views/layouts/_navbar.html.erb

```erb
<nav class="navbar navbar-expand-sm navbar-knowsomenow" data-controller="navbar" data-action="scroll@window->navbar#updateNavbar">
  <div class="container-xl">
    <%= link_to root_path, class: "navbar-brand" do %>
      <%= image_tag "logo_transparent.png", alt: "Logo" %>
    <% end %>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarSupportedContent">
      <ul class="navbar-nav ms-auto">
        <% if user_signed_in? %>
          <li class="nav-item">
            <%= link_to "My Devices", user_path(current_user), class: "nav-link" %>
          </li>
          <li class="nav-item dropdown">
            <a href="#" class="text-white nav-link dropdown-toggle" id="navbarDropdown" data-bs-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
              <%= current_user.email %>
            </a>
            <div class="dropdown-menu dropdown-menu-end" aria-labelledby="navbarDropdown">
              <%= link_to "Log out", destroy_user_session_path, data: { turbo_method: :delete }, class: "dropdown-item" %>
            </div>
          </li>
        <% else %>
          <li class="nav-item">
            <%= link_to "Login", new_user_session_path, class: "nav-link" %>
          </li>
        <% end %>
      </ul>
    </div>
  </div>
</nav>
```

---

## app/views/pages/home.html.erb

```erb
<!-- HERO -->
<section class="container-xl py-5 py-lg-6">
  <div class="row align-items-center g-5">
    <div class="col-lg-6">
      <div class="mb-3 ksn-eyebrow">AI-Powered Device Training</div>
      <h1 class="display-4 fw-black ksn-title mb-3">
        Learn how to use any device, <span class="ksn-text-primary">instantly.</span>
      </h1>
      <p class="lead ksn-lead mb-4">
        Master your iPhone, Kindle, or Smart Home in minutes with AI-powered, step-by-step guidance tailored to your experience level.
      </p>
      <div class="d-grid gap-3 d-sm-flex justify-content-sm-start">
        <%= link_to "Register Now", new_user_registration_path, class: "btn ksn-btn-primary btn-lg px-5 py-3 fw-bold shadow-sm" %>
        <%= link_to "Log In", new_user_session_path, class: "btn btn-outline-light btn-lg px-5 py-3 fw-bold shadow-sm" %>
      </div>
    </div>
    <div class="col-lg-6">
      <div class="ksn-hero-visual p-4 p-md-5">
        <div class="row g-3 h-100">
          <div class="col-8">
            <div class="ksn-hero-chat h-100 p-4">
              <div class="d-flex align-items-center gap-2 mb-3">
                <div class="ksn-badge-icon"><span class="material-symbols-outlined">robot_2</span></div>
                <div class="ksn-skeleton ksn-skeleton-sm" style="width: 120px;"></div>
              </div>
              <div class="vstack gap-2">
                <div class="ksn-skeleton"></div>
                <div class="ksn-skeleton" style="width: 85%;"></div>
                <div class="ksn-skeleton" style="width: 65%;"></div>
                <div class="ksn-skeleton ksn-skeleton-primary"></div>
              </div>
              <div class="d-flex justify-content-between align-items-center mt-4">
                <div class="d-flex">
                  <div class="ksn-avatar"></div>
                  <div class="ksn-avatar ksn-avatar-2"></div>
                </div>
                <div class="ksn-pill"></div>
              </div>
            </div>
          </div>
          <div class="col-4">
            <div class="ksn-hero-tile ksn-hero-tile-primary mb-3">
              <span class="material-symbols-outlined">smartphone</span>
            </div>
            <div class="ksn-hero-tile ksn-hero-tile-light">
              <span class="material-symbols-outlined">nest_thermostat</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>
<!-- POPULAR DEVICES -->
<section class="container-xl py-5" id="guides">
  <div class="d-flex align-items-center justify-content-between mb-4">
    <h2 class="h3 fw-bold mb-0">Popular Devices</h2>
  </div>
  <div class="row g-3 g-md-4">
    <div class="col-6 col-sm-4 col-md-3 col-lg-2">
      <div class="ksn-device-card">
        <div class="ksn-device-icon ksn-device-icon-primary">
          <span class="material-symbols-outlined">smartphone</span>
        </div>
        <div>
          <div class="ksn-device-title">iPhone</div>
          <div class="ksn-device-sub">iOS 17+ Guides</div>
        </div>
      </div>
    </div>
    <div class="col-6 col-sm-4 col-md-3 col-lg-2">
      <div class="ksn-device-card">
        <div class="ksn-device-icon ksn-device-icon-green">
          <span class="material-symbols-outlined">android</span>
        </div>
        <div>
          <div class="ksn-device-title">Android</div>
          <div class="ksn-device-sub">Samsung & Pixel</div>
        </div>
      </div>
    </div>
    <div class="col-6 col-sm-4 col-md-3 col-lg-2">
      <div class="ksn-device-card">
        <div class="ksn-device-icon ksn-device-icon-slate">
          <span class="material-symbols-outlined">laptop_mac</span>
        </div>
        <div>
          <div class="ksn-device-title">Mac</div>
          <div class="ksn-device-sub">macOS Sonoma</div>
        </div>
      </div>
    </div>
    <div class="col-6 col-sm-4 col-md-3 col-lg-2">
      <div class="ksn-device-card">
        <div class="ksn-device-icon ksn-device-icon-blue">
          <span class="material-symbols-outlined">window</span>
        </div>
        <div>
          <div class="ksn-device-title">Windows</div>
          <div class="ksn-device-sub">Windows 11 Tips</div>
        </div>
      </div>
    </div>
    <div class="col-6 col-sm-4 col-md-3 col-lg-2">
      <div class="ksn-device-card">
        <div class="ksn-device-icon ksn-device-icon-orange">
          <span class="material-symbols-outlined">home_iot_device</span>
        </div>
        <div>
          <div class="ksn-device-title">Smart Home</div>
          <div class="ksn-device-sub">IoT & Security</div>
        </div>
      </div>
    </div>
  </div>
</section>
<!-- FEATURES -->
<section class="ksn-section-divider py-5 py-lg-6" id="features">
  <div class="container-xl">
    <div class="row g-4 g-lg-5 text-center">
      <div class="col-md-4">
        <div class="ksn-feature">
          <div class="ksn-feature-icon"><span class="material-symbols-outlined">chat_bubble</span></div>
          <h4 class="h5 fw-bold mt-3">Conversational Help</h4>
          <p class="ksn-muted mb-0">Ask questions naturally and get answers that understand your context.</p>
        </div>
      </div>
      <div class="col-md-4">
        <div class="ksn-feature">
          <div class="ksn-feature-icon"><span class="material-symbols-outlined">menu_book</span></div>
          <h4 class="h5 fw-bold mt-3">Step-by-Step</h4>
          <p class="ksn-muted mb-0">Interactive walkthroughs that wait for you to complete each action.</p>
        </div>
      </div>
      <div class="col-md-4">
        <div class="ksn-feature">
          <div class="ksn-feature-icon"><span class="material-symbols-outlined">verified</span></div>
          <h4 class="h5 fw-bold mt-3">Always Up to Date</h4>
          <p class="ksn-muted mb-0">Our AI stays synced with the latest software updates and hardware releases.</p>
        </div>
      </div>
    </div>
  </div>
</section>
```

---

## app/views/users/show.html.erb

```erb
<div class="container py-5">
  <div class="row justify-content-center">
    <div class="col-12 col-md-8 col-lg-6">
      <div class="card shadow-sm mb-5 border-0 bg-light p-4">
        <h3 class="mb-3">Add New Device</h3>
        <%= simple_form_for Device.new, url: devices_path do |f| %>
          <div class="form-inputs mb-3">
            <%= f.input :name, label: "What device do you need help with?", placeholder: "e.g. Nespresso machine, iPhone 15, Microwave..." %>
          </div>
          <div class="form-actions">
            <%= f.button :submit, "Get AI Instructions", class: "btn btn-primary w-100" %>
          </div>
        <% end %>
      </div>
    </div>
  </div>

  <h3 class="mb-4">My Saved Instructions</h3>
  <% if @user.devices.any? %>
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
      <%= render partial: "devices/device", collection: @user.devices.order(created_at: :desc) %>
    </div>
  <% else %>
    <div class="text-center py-5 border rounded bg-white shadow-sm">
      <p class="text-muted mb-0">You haven't added any devices yet. Type one above!</p>
    </div>
  <% end %>
</div>
```

---

## app/views/devices/show.html.erb

```erb
<div class="container">
  <div class="device-show">
  <% if @device.instruction %>
    <div class="instruction-section">
      <h2>Instructions</h2>
    <div class="steps">
      <%= markdown(@device.instruction.steps) %>
    </div>
    </div>
  <% else %>
    <p class="no-instructions">No instructions available for this device yet.</p>
  <% end %>
  </div>
<%= simple_form_for [@device, @device.instruction],
                    url: device_instruction_path(@device, @device.instruction),
                    method: :patch,
                    html: { class: 'form-horizontal' } do |f| %>

  <%= f.input :steps,
              as: :text,
              label: false,
              placeholder: "Ask for clarification or improvement for a specific part...",
              input_html: {
                class: 'form-control',
                rows: 5,
                value: ''
              },
              wrapper_html: {
                class: 'no-validation-tick'
              },
              validate: false,
              required: false,
              error: false,
              hint: false
              %>

  <%= f.button :submit, "Update Instructions", class: 'btn btn-primary mt-3' %>
<% end %>
  <%= button_to "Delete",
                device_path(@device),
                method: :delete,
                data: { turbo_confirm: "Are you sure?" },
                class: "btn btn-danger my-5" %>

</div>
```

---

## app/views/devices/_device.html.erb

```erb
<%# app/views/devices/_device.html.erb %>
<div class="col">
  <div class="card h-100 shadow-sm border-0">
    <% if device.image.present? %>
      <%= image_tag device.image, class: "card-img-top", style: "height: 160px; object-fit: cover;" %>
    <% else %>
      <div class="d-flex align-items-center justify-content-center bg-light" style="height: 160px;">
        <span class="material-symbols-outlined text-secondary" style="font-size: 56px;">devices</span>
      </div>
    <% end %>

    <div class="card-body d-flex flex-column">
      <h5 class="card-title fw-bold mb-1"><%= device.name %></h5>
      <small class="text-muted mb-2">Added <%= time_ago_in_words(device.created_at) %> ago</small>

      <p class="card-text text-muted small flex-grow-1">
        <% if device.instruction %>
          <%= truncate(strip_tags(markdown(device.instruction.steps)), length: 120) %>
        <% else %>
          No instructions generated yet.
        <% end %>
      </p>

      <%= link_to "Read more", device_path(device), class: "btn btn-primary btn-sm mt-3 align-self-start" %>
    </div>
  </div>
</div>
```

---

## app/assets/stylesheets/application.scss

```scss
@import "config/fonts";
@import "config/colors";
@import "config/bootstrap_variables";
@import "bootstrap";
@import "font-awesome";
@import "components/index";
@import "pages/index";
@import "components/navbar";

.card-body {
  p {
    margin-bottom: 0.5rem;
    color: #444;
    line-height: 1.5;
  }
}
.bg-light {
  background-color: #f8f9fa !important;
}
body {
  padding-top: 70px;
}
```

---

## app/javascript/application.js

```javascript
import "@hotwired/turbo-rails"
import "controllers"
import "@popperjs/core"
import "bootstrap"
```

---

## config/importmap.rb

```ruby
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@popperjs/core", to: "popper.js", preload: true
```

---

**Note:** .env, Gemfile.lock, devise views, and test files are omitted. Add any specific file or change request when you paste this into ChatGPT.
