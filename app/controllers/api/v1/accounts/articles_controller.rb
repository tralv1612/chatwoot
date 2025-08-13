class Api::V1::Accounts::ArticlesController < Api::V1::Accounts::BaseController
  before_action :portal
  before_action :check_authorization
  before_action :fetch_article, except: [:index, :create, :reorder]
  before_action :set_current_page, only: [:index]

  def index
    @portal_articles = @portal.articles

    set_article_count

    @articles = @articles.search(list_params)

    @articles = if list_params[:category_slug].present?
                  @articles.order_by_position.page(@current_page)
                else
                  @articles.order_by_updated_at.page(@current_page)
                end
  end

  def show; end
  def edit; end

  def create
    @article = @portal.articles.create!(article_params)
    @article.associate_root_article(article_params[:associated_article_id])
    @article.draft!
    render json: { error: @article.errors.messages }, status: :unprocessable_entity and return unless @article.valid?
  end

  def update
    if @article.update(article_params)
      # Gửi webhook sau khi cập nhật thành công
      send_article_update_webhook(@article)
      render json: @article
    else
      render json: { error: @article.errors.messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy!
    head :ok
  end

  def reorder
    Article.update_positions(params[:positions_hash])
    head :ok
  end

  private

  def send_article_update_webhook(article)
    # Lấy URL webhook từ biến môi trường để bảo mật và linh hoạt
    webhook_url = ENV.fetch('N8N_ARTICLE_UPDATE_WEBHOOK_URL', nil)
    return unless webhook_url.present?

    begin
      uri = URI.parse(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')

      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      # Chuyển đổi dữ liệu bài viết thành JSON để gửi đi
      request.body = { article: article.as_json }.to_json

      response = http.request(request)

      # Ghi lại kết quả (tùy chọn nhưng được khuyến nghị)
      Rails.logger.info "Webhook sent for article #{article.id}. Response: #{response.code} #{response.message}"
    rescue StandardError => e
      # Ghi lại bất kỳ lỗi nào xảy ra trong quá trình gửi webhook
      Rails.logger.error "Failed to send webhook for article #{article.id}: #{e.message}"
    end
  end

  def set_article_count
    # Search the params without status and author_id, use this to
    # compute mine count published draft etc
    base_search_params = list_params.except(:status, :author_id)
    @articles = @portal_articles.search(base_search_params)

    @articles_count = @articles.count
    @mine_articles_count = @articles.search_by_author(Current.user.id).count
    @published_articles_count = @articles.published.count
    @draft_articles_count = @articles.draft.count
    @archived_articles_count = @articles.archived.count
  end

  def fetch_article
    @article = @portal.articles.find(params[:id])
  end

  def portal
    @portal ||= Current.account.portals.find_by!(slug: params[:portal_id])
  end

  def article_params
    params.require(:article).permit(
      :title, :slug, :position, :content, :description, :category_id, :author_id, :associated_article_id, :status,
      :locale, meta: [:title,
                      :description,
                      { tags: [] }]
    )
  end

  def list_params
    params.permit(:locale, :query, :page, :category_slug, :status, :author_id)
  end

  def set_current_page
    @current_page = params[:page] || 1
  end
end
