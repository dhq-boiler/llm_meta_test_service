class PromptsController < ApplicationController
  include ChatManager::ChatManageable
  include PromptNavigator::HistoryManageable
  skip_before_action :authenticate_user!, raise: false

  def show
    @prompt_execution = PromptNavigator::PromptExecution.find_by!(execution_id: params[:id])
    @message = Message.where(prompt_navigator_prompt_execution: @prompt_execution).order(:created_at).first
    @chat = @message.chat
    @messages = @chat.ordered_messages

    # Initialize chat context
    initialize_chat current_user&.chats

    # Initialize history
    initialize_history @chat.ordered_by_descending_prompt_executions

    # Get LLM options available for users
    jwt_token = current_user.id_token if user_signed_in?
    @llm_families = LlmMetaClient::ServerResource.available_llm_families(jwt_token)

    # Set the target message ID for scrolling
    @target_message_id = @message.id

    # Set active UUID for history sidebar highlighting
    set_active_message_uuid(@prompt_execution.execution_id)

    render "chats/edit"
  rescue StandardError => e
    Rails.logger.error "Error in PromptsController#show_by_uuid: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
    redirect_to root_path, alert: "Message not found."
  end
end
