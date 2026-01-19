class LlmMetaServerResource
  # This is a non-persisted model for fetching external server resources

  class << self
    # Retrieve LLM options available for user selection (API Keys + Ollama)
    # For guest users (no jwt_token), only Ollama is returned
    def available_llm_options(jwt_token)
      # For guest users: Ollama is required
      # return only Ollama
      return format ollama_options if jwt_token.blank?

      # Logged-in user: return API Keys + Ollama (if available)
      options = llm_api_keys jwt_token

      # Try to add Ollama, but don't fail if unavailable
      begin
        options.concat ollama_options
      rescue Exceptions::OllamaUnavailableError => e
        Rails.logger.warn "Ollama unavailable: #{e.message}"
        # Continue with API Keys only if at least one is available
        raise e if options.empty?
      end

      format options
    end

    private

    def ollama_options
      ollama_list = llms.filter { it["llm_type"] == "ollama" }
      raise Exceptions::OllamaUnavailableError if ollama_list.empty?
      ollama_list
    end

    # Builds normalized option hashes from an array of resources by slicing common keys
    # Accepts only arrays
    def format(resources)
      common_keys = %w[uuid description llm_type available_models]
      resources.map { it.slice(*common_keys).symbolize_keys }
    end

    def llms
      api_url = "#{Rails.configuration.llm_service_base_url}/api/llms"
      headers = { "Content-Type" => "application/json" }

      response = HTTParty.get api_url, headers: headers

      if response.success?
        response.parsed_response["llms"] || []
      else
        Rails.logger.error "Failed to fetch LLMs: HTTP #{response.code}"
        []
      end
    end

    def llm_api_keys(jwt_token)
      api_url = "#{Rails.configuration.llm_service_base_url}/api/llm_api_keys"
      headers = { "Content-Type" => "application/json", "Authorization" => "Bearer #{jwt_token}" }

      response = HTTParty.get api_url, headers: headers

      if response.success?
        response.parsed_response["llm_api_keys"] || []
      else
        Rails.logger.error "Failed to fetch LLM API keys: HTTP #{response.code}"
        []
      end
    end
  end
end
