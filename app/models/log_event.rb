# == Schema Information
#
# Table name: log_events
#
#  id         :bigint           not null, primary key
#  event_name :string
#  link       :string
#  time       :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  contact_id :bigint           not null
#  inbox_id   :bigint           not null
#  source_id  :string
#
# Indexes
#
#  index_log_events_on_account_id  (account_id)
#  index_log_events_on_contact_id  (contact_id)
#  index_log_events_on_inbox_id    (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class LogEvent < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :contact
end
