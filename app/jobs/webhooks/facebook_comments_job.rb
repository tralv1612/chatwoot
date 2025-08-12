class Webhooks::FacebookCommentsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(message)
    response = ::Integrations::Facebook::CommentParser.new(message)

    return unless response.verb == 'add'

    key = format(::Redis::Alfred::FACEBOOK_COMMENT_MUTEX, user_id: response.customer_id, post_id: response.post_id)
    with_lock(key) do
      process_message(response)
    end
  end

  def process_message(response)
    ::Integrations::Facebook::CommentCreator.new(response).perform
  end
end
