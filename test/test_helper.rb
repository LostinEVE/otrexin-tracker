ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Keep SQLite-backed tests stable on Windows by default; CI can opt in.
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", "1").to_i)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end

  module AuthenticationHelpers
    def sign_in_as(user, password: "password123")
      post login_url, params: { email: user.email, password: password }
      assert_response :redirect
    end
  end
end

class ActionDispatch::IntegrationTest
  include ActiveSupport::AuthenticationHelpers
end
