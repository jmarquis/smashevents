# == Schema Information
#
# Table name: notifications
#
#  id                :bigint           not null, primary key
#  metadata          :json
#  notifiable_type   :string           not null
#  notification_type :string           not null
#  platform          :string           not null
#  sent_at           :datetime         not null
#  success           :boolean          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  notifiable_id     :bigint           not null
#
# Indexes
#
#  index_notifications_on_notifiable  (notifiable_type,notifiable_id)
#

require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
