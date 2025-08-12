class Messages::Facebook::CommentBuilder < Messages::Messenger::MessageBuilder
  attr_reader :response

  def initialize(response, inbox, outgoing_echo: false)
    super()
    @response = response
    @inbox = inbox
    @outgoing_echo = outgoing_echo
    @sender_id = response.identifier
    @message_type = (@outgoing_echo ? :outgoing : :incoming)
    @attachments = []
  end

  def perform
    return if @inbox.channel.reauthorization_required?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      build_message
    end
  rescue Koala::Facebook::AuthenticationError => e
    Rails.logger.warn("Facebook authentication error for inbox: #{@inbox.id} with error: #{e.message}")
    Rails.logger.error e
    @inbox.channel.authorization_error!
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @inbox.account).capture_exception
    true
  end

  private

  def graph_api
    @graph_api ||= Koala::Facebook::API.new(@inbox.channel.page_access_token)
  end

  def build_contact_inbox
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: @sender_id,
      inbox: @inbox,
      contact_attributes: contact_params
    ).perform
  end

  def build_message
    existing_message = conversation.messages.find_by(source_id: response.comment_id)
    return if existing_message.present?

    @message = conversation.messages.create!(message_params)

    @attachments.each do |attachment|
      process_attachment(attachment)
    end
  end

  def conversation
    @conversation ||= set_conversation_based_on_inbox_config
  end

  def set_conversation_based_on_inbox_config
    if @inbox.lock_to_single_conversation
      Conversation.where(conversation_params).order(created_at: :desc).first || build_conversation
    else
      find_or_build_for_multiple_conversations
    end
  end

  def find_or_build_for_multiple_conversations
    last_conversation = Conversation.where(conversation_params).where.not(status: :resolved).order(created_at: :desc).first
    return build_conversation if last_conversation.nil?

    last_conversation
  end

  def build_conversation
    conversation = Conversation.create!(conversation_params.merge(
                                          contact_inbox_id: @contact_inbox.id
                                        ))
    add_post_content_as_private_note(conversation)

    conversation
  end

  def add_post_content_as_private_note(conversation)
    post_content = fetch_facebook_post_content
    return if post_content.blank?

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      private: true,
      content: post_content,
      sender: nil,
      source_id: 'facebook_post_content'
    )
  rescue StandardError => e
    # Ghi log lỗi nếu có sự cố xảy ra để không làm dừng toàn bộ quá trình
    Rails.logger.error "Facebook Comment Builder: Could not create private note for post #{response.post_id}. Error: #{e.message}"
  end

  def fetch_facebook_post_content
    post_data = graph_api.get_object(response.post_id, fields: 'message')
    post_data['message']
  rescue Koala::Facebook::APIError => e
    Rails.logger.error "Facebook API Error: Could not fetch post content for #{response.post_id}. Error: #{e.message}"
    nil
  end

  def location_params(attachment)
    lat = attachment['payload']['coordinates']['lat']
    long = attachment['payload']['coordinates']['long']
    {
      external_url: attachment['url'],
      coordinates_lat: lat,
      coordinates_long: long,
      fallback_title: attachment['title']
    }
  end

  def fallback_params(attachment)
    {
      fallback_title: attachment['title'],
      external_url: attachment['url']
    }
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      additional_attributes: {
        type: 'facebook_comment',
        post_id: response.post_id,
        comment_id: response.identifier
      }
    }
  end

  def message_params
    {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: @message_type,
      content: response.content,
      source_id: response.comment_id,
      content_attributes: {
        customer_id: response.customer_id
      },
      sender: @outgoing_echo ? nil : @contact_inbox.contact
    }
  end

  def contact_params
    {
      name: @response.customer_name || 'John Doe',
      account_id: @inbox.account_id
    }
  end
end
