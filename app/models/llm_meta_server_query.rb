
class LlmMetaServerQuery
  def call(id_token, api_key_uuid, model_id, user_content)
    Rails.logger.info "Request to LLM: \n===>\n#{user_content}\n===>" if Rails.env.development?
    response = request(api_key_uuid, id_token, model_id, user_content)
    response_body = response.parsed_response
    content = response_body.dig("response", "message") || ""

    Rails.logger.info "Response from LLM: \n<===\n#{content}\n<===" if Rails.env.development?

    content
  end

  private

  def request(api_key_uuid, id_token, model_id, user_content)
    HTTParty.post(
      url(api_key_uuid, model_id),
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{id_token}"
      },
      body: { prompt: "#{user_content}" }.to_json,
      timeout: 300 # 5 minute timeout setting (both read and connect)
    )
  end

  def url(api_key_uuid, model_id)
    "#{Rails.application.config.llm_service_base_url}/api/llm_api_keys/#{api_key_uuid}/models/#{model_id}/chats"
  end
end
