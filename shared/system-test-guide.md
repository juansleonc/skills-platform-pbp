# System Test Guide (Playwright)

System tests live in `system_specs/` (NOT `spec/`). Full reference for Playwright-based browser tests.

## Playwright Version (CRITICAL)

Version MUST match between gem and CLI:

```bash
# Check current version in Gemfile.lock
grep "capybara-playwright-driver" Gemfile.lock

# Install matching CLI version
npx --yes playwright@1.55.0 install chromium
```

## Running System Tests

```bash
# Setup Playwright (version must match!)
npx --yes playwright@1.55.0 install chromium

# Run all system tests
bin/test_system

# Parallel execution
PARALLEL_TEST_PROCESSORS=4 bin/test_system

# Visible browser (debugging)
PLAYWRIGHT_HEADLESS=false bin/test_system

# Single test
bin/d rspec system_specs/features/admin_login_spec.rb
```

## System Test File Structure

```ruby
# frozen_string_literal: true
require_relative '../system_rails_helper'

RSpec.describe 'Feature Name', type: :system, playwright: true do
  # Test content
end
```

## Multi-Tenant Setup

```ruby
# Always create unique emails with SecureRandom to avoid parallel test collisions
let(:admin_user) do
  FactoryBot.create(
    :user,
    :admin,
    email: "admin_#{SecureRandom.hex(4)}@example.com",
    password: password,
    confirmed_at: Time.current
  ).tap do |u|
    FacilitiesUser.create!(user: u, facility: facility, role: 'court_manager', approval: true)
    u.facilities_linked << facility
  end
end

# Use visit_as_tenant for subdomain routing
def login_user(user, subdomain:)
  visit_as_tenant('/users/sign_in', subdomain: subdomain)
  fill_in('Email', with: user.email)
  fill_in('Password', with: password)
  click_button('Sign in')
  expect(page).to have_current_path(%r{/admin|/facilities}, wait: 10)
end
```

## Available Helpers (auto-included)

```ruby
include SystemTestHelpers::MultiTenant  # visit_as_tenant, sign_in_user
include SystemTestHelpers::Waiting      # wait_for_element, wait_for_text, wait_for_ajax
include SystemTestHelpers::Screenshots  # take_screenshot (auto on failure)
include SystemTestHelpers::FormHelpers  # fill_in_date_field, select_from_dropdown
```

## Waiting for Dynamic Content

```ruby
# Prefer Capybara's built-in waiting over custom waits
expect(page).to have_css('selector', wait: 10)
expect(page).to have_content('text', wait: 10)

# For AJAX/fetch updates, wait for specific elements
def wait_for_search_results
  expect(page).to have_no_css('.loading', wait: 5)
  expect(page).to have_css('#results-table tbody tr', wait: 10)
end
```

## Full System Test Template

```ruby
# frozen_string_literal: true
require_relative '../system_rails_helper'

RSpec.describe 'Admin Login', type: :system, playwright: true do
  let(:password) { 'password123!' }
  let(:facility) { FactoryBot.create(:facility, :skip_callbacks) }
  let(:admin_user) do
    FactoryBot.create(
      :user,
      :admin,
      email: "admin_#{SecureRandom.hex(4)}@example.com",
      password: password,
      confirmed_at: Time.current
    ).tap do |u|
      FacilitiesUser.create!(user: u, facility: facility, role: 'court_manager', approval: true)
    end
  end

  it 'allows admin to login' do
    visit_as_tenant('/users/sign_in', subdomain: facility.subdomain)

    fill_in 'Email', with: admin_user.email
    fill_in 'Password', with: password
    click_button 'Sign in'

    expect(page).to have_current_path(%r{/admin}, wait: 10)
    expect(page).to have_content('Dashboard')
  end
end
```

## Key Patterns

1. **Unique identifiers**: Always use `SecureRandom.hex(4)` in emails/names for parallel safety
2. **Explicit waits**: Use Capybara's `wait:` option, not `sleep`
3. **Asset precompilation**: Run `RAILS_ENV=test rails assets:precompile` after JS changes
4. **Pending specs**: Use `pending 'reason'` for known issues, not `skip`
5. **Screenshots**: Automatic on failure to `tmp/screenshots/playwright/`
