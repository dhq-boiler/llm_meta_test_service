class MessagesController < ApplicationController
  include HistoryManageable
  skip_before_action :authenticate_user!, raise: false

  def show_by_uuid
    @prompt_execution = PromptManager::PromptExecution.find_by(execution_id: params[:uuid])
    @message = Message.joins(message_prompt_execution: :prompt_execution)
                      .includes(:chat)
                      .find_by(prompt_manager_prompt_executions: { execution_id: params[:uuid] })
    @chat = @message.chat
    @messages = @chat.ordered_messages

    # Initialize history
    initialize_history @chat.ordered_by_descending_prompt_executions

    # Get LLM options available for users
    jwt_token = current_user.id_token if user_signed_in?
    @llm_options = LlmMetaServerResource.available_llm_options(jwt_token)

    # Set the target message ID for scrolling
    @target_message_id = @message.id

    # Set active UUID for history sidebar highlighting
    set_active_message_uuid(@prompt_execution.execution_id)

    render "chats/edit"
  rescue StandardError => e
    Rails.logger.error "Error in MessagesController#show_by_uuid: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
    redirect_to root_path, alert: "Message not found."
  end
end
