# encoding: utf-8
require 'test_helper'

# Execution of WorkerThreadTest is precondition for successful run (initial table creation must be executed before this test)

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  include MenuHelper

  # Test for XSS vulnerability in parameters
  test "check_params_4_vulnerability with xhr: true" do
    [
      "<SCRiPT>alert('Evil');</script>",
      "<SCRIPT>alert('Evil');</script>",
      "<scrIpt>alert('Evil');</script>",
      { wrapped: "<SCRiPT>alert('Evil');</script>" }
    ].each do |param|
      post '/env/set_database_by_params', params: { format: :html, evil: param }
      assert_response :error
    end
  end
end
