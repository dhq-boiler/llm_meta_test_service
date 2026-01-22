class ChatChannel < ApplicationCable::Channel
  def subscribed
    chat = Chat.find_by(id: params[:chat_id])
    if chat
      stream_name = "chat_#{chat.id}"
      Rails.logger.info "Subscribing to: #{stream_name}"
      stream_from stream_name
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
