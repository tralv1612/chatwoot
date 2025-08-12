class Integrations::Facebook::CommentCreator
  attr_reader :response

  def initialize(response)
    @response = response
  end

  def perform
    if response.send_from_page?
      create_agent_message
    else
      create_contact_message
    end
  end

  private

  def create_agent_message
    Channel::FacebookPage.where(page_id: response.page_id).each do |page|
      mb = Messages::Facebook::CommentBuilder.new(response, page.inbox, outgoing_echo: true)
      mb.perform
    end
  end

  def create_contact_message
    Channel::FacebookPage.where(page_id: response.page_id).each do |page|
      mb = Messages::Facebook::CommentBuilder.new(response, page.inbox)
      mb.perform
    end
  end
end
