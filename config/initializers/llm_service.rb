# frozen_string_literal: true

# LLM Service Configuration
# External LLM service base URL for API key and model management
Rails.application.configure do
  # Base URL for LLM service
  # Retrieved from environment variable LLM_SERVICE_BASE_URL, uses default value if not set
  config.llm_service_base_url = ENV.fetch("LLM_SERVICE_BASE_URL", "http://localhost:3000")
end
