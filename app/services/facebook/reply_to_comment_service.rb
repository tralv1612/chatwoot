class Facebook::ReplyToCommentService < Base::SendOnChannelService
  private

  def channel_class
    Channel::FacebookPage
  end

  def perform_reply
    parent_comment_id = message.conversation.additional_attributes['comment_id']
    unless parent_comment_id
      Rails.logger.error "Facebook::ReplyToCommentService: Missing parent_comment_id for message #{message.id}"
      return
    end

    # Gửi trả lời dưới dạng văn bản
    if message.content.present?
      result = reply_to_comment(parent_comment_id, text_reply_params)
      update_message_status(result)
    end
    # Gửi trả lời dưới dạng hình ảnh (hoặc tệp đính kèm khác nếu API hỗ trợ)
    if message.attachments.present?
      message.attachments.each do |attachment|
        # API trả lời bình luận bằng hình ảnh phức tạp hơn, đây là một ví dụ
        result = reply_to_comment(parent_comment_id, attachment_reply_params(attachment))
        update_message_status(result)
      end
    end

  rescue Koala::Facebook::ClientError => e
    # Xử lý các lỗi cụ thể từ Graph API (vd: không có quyền, bình luận đã bị xóa)
    handle_koala_error(e)
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
  end

  # Phương thức thực hiện cuộc gọi API thực sự
  def reply_to_comment(comment_id, params)
    graph_api.put_comment(comment_id, params[:message])
  end

  def update_message_status(result)
    # Koala trả về một hash {'id' => 'COMMENT_ID'} khi thành công
    if result && result['id'].present?
      # Cập nhật cả source_id và status
      message.update!(
        source_id: result['id'],
        status: :sent
      )
      Rails.logger.info "Facebook::ReplyToCommentService: Successfully replied to comment. New comment ID: #{result['id']}"
    else
      # Trường hợp API không báo lỗi nhưng cũng không trả về ID
      Messages::StatusUpdateService.new(message, 'failed', 'Facebook did not return a valid response.').perform
      Rails.logger.warn "Facebook::ReplyToCommentService: Failed to reply. Facebook response: #{result}"
    end
  end

  # Khởi tạo client cho Graph API
  def graph_api
    @graph_api ||= Koala::Facebook::API.new(channel.page_access_token)
  end

  # Chuẩn bị tham số cho trả lời văn bản
  def text_reply_params
    {
      message: message.outgoing_content
    }
  end

  def attachment_reply_params(attachment)
    {
      message: "#{message.outgoing_content} #{attachment.download_url}".strip
    }
    # Nếu muốn upload ảnh thực sự, bạn sẽ cần dùng phương thức khác của Koala.
  end

  def handle_koala_error(exception)
    channel.authorization_error! if exception.fb_error_code == 190
    Rails.logger.error "Facebook::ReplyToCommentService: Error replying to comment: #{exception.message}"
  end
end
