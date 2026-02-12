class ChatsController < ApplicationController
  include ChatManager::ChatManageable
  include ChatManager::CsvDownloadable
  include PromptManager::HistoryManageable
  # Allow access without login
  skip_before_action :authenticate_user!, raise: false

  def show
    @chat = Chat.includes(:messages).find(params[:id])
    @messages = @chat.ordered_messages

    # Initialize history
    initialize_history @chat.ordered_by_descending_prompt_executions

    # Get LLM options available for users
    jwt_token = current_user&.id_token if user_signed_in?
    @llm_options = LlmMetaServerResource.available_llm_options(jwt_token)

    # Set active UUID for history sidebar highlighting
    set_active_message_uuid(@prompt_execution.execution_id)

    render "chats/edit"
  rescue StandardError => e
    Rails.logger.error "Error in PromptsController#show: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
    redirect_to root_path, alert: "Message not found."
  end

  def new
    # Find current conversation or create it on create method if not found
    @chat = Chat.find_or_switch_for_session(
      session,
      current_user
    )
    @messages = @chat&.ordered_messages || []
    # initialize history for the chat
    initialize_history @chat&.ordered_by_descending_prompt_executions

    # Get LLM options available for users
    jwt_token = current_user&.id_token if user_signed_in?
    @llm_options = LlmMetaServerResource.available_llm_options(jwt_token)
  rescue StandardError => e
    Rails.logger.error "Error in ChatsController#new: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
    @llm_options = []
    flash.now[:alert] = "Chat service is currently unavailable. Please try again later."
  end

  def create
    jwt_token = current_user&.id_token if user_signed_in?

    # Find or create chat
    @chat = Chat.find_or_switch_for_session(
      session,
      current_user,
      llm_uuid: params[:api_key_uuid],
      model: params[:model]
    )
    @messages = @chat&.ordered_messages || []

    # initialize history for the chat
    initialize_history @chat&.ordered_by_descending_prompt_executions

    if params[:message].present?
      # Add user message (will be rendered via turbo stream)
      @prompt_execution, @user_message = @chat.add_user_message(params[:message],
                                                                params[:model],
                                                                params[:branch_from_uuid])
      # Push to history for rendering
      push_to_history @prompt_execution
      # Set active message UUID for highlighting in UI
      set_active_message_uuid(@prompt_execution&.execution_id || params.dig(:chat, :branch_from_uuid))

      # Send to LLM and get assistant response
      begin
        @assistant_message = @chat.add_assistant_response(@prompt_execution, jwt_token)
      rescue StandardError => e
        Rails.logger.error "Error in chat response: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
        @error_message = "An error occurred while getting the response. Please try again."
      end
    end

    # Return turbo stream to render both messages
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to new_chat_path }
    end
  end

  def edit
    # Get LLM options available for users
    jwt_token = current_user&.id_token if user_signed_in?
    @llm_options = LlmMetaServerResource.available_llm_options(jwt_token)

    @chat = Chat.find_or_switch_for_session(
      session,
      current_user,
      llm_uuid: params[:api_key_uuid],
      model: params[:model]
    )
    @messages = @chat&.ordered_messages || []
    # initialize history for the chat
    initialize_history @chat&.ordered_by_descending_prompt_executions
    # Set active message UUID for highlighting in UI
    set_active_message_uuid(params.dig(:chat, :branch_from_uuid))
  rescue StandardError => e
    Rails.logger.error "Error in ChatsController#edit: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
    @llm_options = []
    flash.now[:alert] = "Chat service is currently unavailable. Please try again later."
  end

  def update
    jwt_token = current_user&.id_token if user_signed_in?

    # Find or create chat
    @chat = Chat.find_or_switch_for_session(
      session,
      current_user,
      llm_uuid: params[:api_key_uuid],
      model: params[:model]
    )
    @messages = @chat&.ordered_messages || []
    # initialize history for the chat
    initialize_history @chat&.ordered_by_descending_prompt_executions

    if params[:message].present?
      # Add user message (will be rendered via turbo stream)
      @prompt_execution, @user_message = @chat.add_user_message(params[:message],
                                                               params[:model],
                                                               params[:branch_from_uuid])
      # Push to history for rendering
      push_to_history @prompt_execution
      # Set active message UUID for highlighting in UI
      set_active_message_uuid(@prompt_execution&.execution_id || params.dig(:chat, :branch_from_uuid))

      # Send to LLM and get assistant response
      begin
        @assistant_message = @chat.add_assistant_response(@prompt_execution, jwt_token)
      rescue StandardError => e
        Rails.logger.error "Error in chat response: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}"
        @error_message = "An error occurred while getting the response. Please try again."
      end
    end

    # Return turbo stream to render both messages
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to new_chat_path }
    end
  end
end
