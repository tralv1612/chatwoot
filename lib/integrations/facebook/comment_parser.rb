class Integrations::Facebook::CommentParser
  def initialize(response_json)
    @response = JSON.parse(response_json)
    @messaging = @response['change'] || @response['changes']
  end

  def page_id
    post_id = @messaging.dig('value', 'post_id')
    post_id.split('_').first
  end

  def content
    @messaging.dig('value', 'message')
  end

  def customer_id
    @messaging.dig('value', 'from', 'id')
  end

  def customer_name
    @messaging.dig('value', 'from', 'name')
  end

  def comment_id
    @messaging.dig('value', 'comment_id')
  end

  def parent_id
    @messaging.dig('value', 'parent_id')
  end

  def post_id
    @messaging.dig('value', 'post_id')
  end

  def identifier
    parent_id = @messaging.dig('value', 'parent_id')
    post_id = @messaging.dig('value', 'post_id')
    comment_id = @messaging.dig('value', 'comment_id')

    parent_id == post_id ? comment_id : parent_id
  end

  def post_permalink_url
    @messaging.dig('value', 'post', 'permalink_url')
  end

  def post_status_type
    @messaging.dig('value', 'post', 'status_type')
  end

  def post_is_published?
    @messaging.dig('value', 'post', 'is_published')
  end

  def post_updated_time
    @messaging.dig('value', 'post', 'updated_time')
  end

  def post_promotion_status
    @messaging.dig('value', 'post', 'promotion_status')
  end

  def verb
    @messaging.dig('value', 'verb')
  end

  def created_time
    @messaging.dig('value', 'created_time')
  end

  def send_from_page?
    @messaging.dig('value', 'from', 'id') == page_id
  end
end

# {
#     "changes": [
#     {
#         "value":
#         {
#             "from":
#             {
#                 "id": "240358",
#                 "name": "Ekai",
#             },
#             "post":
#             {
#             "status_type": "mobile_status_update",
#             "is_published": true,
#             "updated_time": "2025-07-15T07:11:38+0000",
#             "permalink_url": "https://www.facebook.com/permalink.php9GoR4eeVx42234",
#             "promotion_status": "inactive",
#             "id": "6712330728"
#             },
#             "message": "xin chào",
#             "post_id": "67123728",
#             "comment_id": "12275047",
#             "created_time": 175498,
#             "item": "comment",
#             "parent_id": "67176728",
#             "verb": "add"
#         },
#         "field": "feed"
#     }
#     ]
