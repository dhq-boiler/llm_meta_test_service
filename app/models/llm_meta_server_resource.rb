class LlmMetaServerResource
  # This is a non-persisted model for fetching external server prompts

  FAMILY_DISPLAY_NAMES = {
    "openai" => "OpenAI",
    "anthropic" => "Anthropic",
    "google" => "Google",
    "ollama" => "Ollama"
  }.freeze

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

    # Retrieve LLM families with their API keys grouped by llm_type
    # Returns: [{name:, llm_type:, api_keys: [{uuid:, description:, available_models:}]}]
    def available_llm_families(jwt_token)
      if jwt_token.blank?
        # Guest users: only Ollama
        return build_families(ollama_options, [])
      end

      api_keys = llm_api_keys(jwt_token)

      ollama_opts = begin
        ollama_options
      rescue Exceptions::OllamaUnavailableError => e
        Rails.logger.warn "Ollama unavailable: #{e.message}"
        raise e if api_keys.empty?
        []
      end

      build_families(ollama_opts, api_keys)
    end

    private

    def build_families(ollama_opts, api_keys)
      # Group user API keys by llm_type
      families = api_keys.group_by { |k| k["llm_type"] }.map do |llm_type, keys|
        {
          name: FAMILY_DISPLAY_NAMES[llm_type] || llm_type.capitalize,
          llm_type: llm_type,
          api_keys: keys.map { |k| format_api_key(k) }
        }
      end

      # Add Ollama family if available
      if ollama_opts.present?
        families << {
          name: FAMILY_DISPLAY_NAMES["ollama"],
          llm_type: "ollama",
          api_keys: ollama_opts.map { |o| format_api_key(o) }
        }
      end

      families
    end

    def format_api_key(resource)
      common_keys = %w[uuid description llm_type available_models]
      resource.slice(*common_keys).symbolize_keys
    end

    def ollama_options
      ollama_list = llms.filter { it["family"] == "ollama" }
      raise Exceptions::OllamaUnavailableError if ollama_list.empty?
      ollama_list
    end

    # Builds normalized option hashes from an array of prompts by slicing common keys
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
