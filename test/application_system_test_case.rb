require "test_helper"
require_relative "test_helpers/system_test_browser"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if SystemTestBrowser.available?
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  else
    driven_by :rack_test

    setup do
      skip "System tests require Chrome and run in GitHub CI. The local Docker image does not include a browser."
    end
  end
end
