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
      "&lt;scrIpt&gt;alert('Evil');&lt;/script&gt;",
      "&#x3C;&#x73;&#x63;&#x72;&#x69;&#x70;&#x74;&#x3E;",                       # <script> as HTML unicode entities
      "&lt; &#x73;c&#x72;I&#x70;&#x74;&#x3E;",                                  # mixedTML unicode entities
      "onload\n = 'alert(1)'",                                                  # Event handler
      { wrapped: "<SCRiPT>alert('Evil');</script>" }
    ].each do |param|
      post '/env/set_database_by_params', params: { format: :html, evil: param }
      assert_response :error
    end
  end
end
