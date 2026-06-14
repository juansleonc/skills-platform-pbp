# Test Templates

Canonical RSpec templates. Reference from `/tdd` — do not duplicate inline.

## Unit / Integration Test Structure

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClassName do
  # Subject first
  subject(:result) { described_class.new(args).method_name }

  # Then lets (dependencies)
  let(:facility) { create(:facility, :skip_callbacks) }
  let(:dependency) { build(:factory) }
  let(:args) { { key: value } }

  # Then contexts with examples
  describe '#method_name' do
    context 'when condition A' do
      it 'behaves as expected' do
        expect(result).to eq(expected)
      end
    end

    context 'when condition B' do
      let(:args) { { key: different_value } }

      it 'behaves differently' do
        expect(result).to eq(different_expected)
      end
    end
  end
end
```

## RED Template (TDD — first test, must fail)

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewFeature do
  describe '#expected_behavior' do
    subject(:result) { described_class.call(input) }

    context 'when happy path' do
      let(:input) { valid_input }

      it 'returns expected output' do
        expect(result).to eq(expected_output)
      end
    end

    context 'when edge case' do
      let(:input) { edge_case_input }

      it 'handles edge case correctly' do
        expect(result).to handle_edge_case
      end
    end

    context 'when error condition' do
      let(:input) { invalid_input }

      it 'raises appropriate error' do
        expect { result }.to raise_error(ExpectedError)
      end
    end
  end
end
```

Run this immediately after writing it:
```bash
bin/d rspec spec/path_spec.rb
# Must be RED — confirm failure says FEATURE IS MISSING, not a load error or typo.
```

## HTTP-Facing Integration Template (GraphQL / controller)

When the code is reached via HTTP, the RED test must exercise the real entry point:

```ruby
# GraphQL resolver spec
RSpec.describe 'Query.someResolver', type: :request do
  it 'returns expected data' do
    graphql_post(query, token, { input: params })
    expect(response_data['someResolver']).to match(expected)
  end
end

# Controller request spec
RSpec.describe SomeController, type: :request do
  it 'returns correct status' do
    post '/endpoint', params: { key: value }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(json_body['result']).to eq(expected)
  end
end
```

Unit tests on `described_class.allocate` or stubs of the framework are NOT sufficient for HTTP-facing code.
