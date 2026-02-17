
class LlmMetaServerQuery
  def call(id_token, api_key_uuid, model_id, context, user_content)
    Rails.logger.info "Context: #{context}" if Rails.env.development?
    context_and_user_content = "Context:#{context}, User Prompt: #{user_content}"
    Rails.logger.info "Request to LLM: \n===>\n#{context_and_user_content}\n===>" if Rails.env.development?

    response = request(api_key_uuid, id_token, model_id, context_and_user_content)
    response_body = response.parsed_response
    content = response_body.dig("response", "message") || ""

    Rails.logger.info "Response from LLM: \n<===\n#{content}\n<===" if Rails.env.development?

    content
  end

  private

  def request(api_key_uuid, id_token, model_id, user_content)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{id_token}" if id_token.present?

    HTTParty.post(
      url(api_key_uuid, model_id),
      headers: headers,
      body: { prompt: "#{user_content}" }.to_json,
      timeout: 300 # 5 minute timeout setting (both read and connect)
    )
  end

  def url(api_key_uuid, model_id)
    "#{Rails.application.config.llm_service_base_url}/api/llm_api_keys/#{api_key_uuid}/models/#{model_id}/chats"
  end
end
