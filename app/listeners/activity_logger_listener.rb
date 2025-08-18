class ActivityLoggerListener
  include Singleton

  def user_is_active(event)
    contact_inbox = event.data[:contact_inbox]
    contact_inbox.inbox

    # Lấy thông tin cần thiết từ các đối tượng có sẵn
    event_name = __method__.to_s
    payload = contact_inbox.webhook_data.merge(event: event_name)
    payload[:event_info] = event.data[:event_info]

    # 2. Trích xuất dữ liệu từ payload để ghi log
    # Sử dụng .dig để truy cập an toàn vào các hash lồng nhau, tránh lỗi nil
    timestamp_str = payload.dig(:event_info, :initiated_at, :timestamp)
    # Chuyển đổi chuỗi thời gian sang đối tượng DateTime, nếu không có thì dùng thời gian hiện tại
    event_time = timestamp_str ? DateTime.parse(timestamp_str) : Time.current

    # 3. Tạo bản ghi log với dữ liệu đã được ánh xạ chính xác
    LogEvent.create!(
      account_id: payload.dig(:account, :id),
      inbox_id: payload.dig(:inbox, :id),
      contact_id: payload.dig(:contact, :id),
      source_id: payload[:source_id],
      event_name: payload[:event],
      time: event_time,
      link: payload.dig(:event_info, :referer) # 'referer' chính là link trang web
    )
  end
end
