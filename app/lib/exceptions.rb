module Exceptions
  class OllamaUnavailableError < StandardError
    def initialize(msg = "Ollama is not available in LLM service. Please contact the administrator.")
      super(msg)
    end
  end
end
