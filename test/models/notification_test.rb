# == Schema Information
#
# Table name: notifications
#
#  id                :integer          not null, primary key
#  notifiable_type   :string           not null
#  notifiable_id     :integer          not null
#  success           :boolean          not null
#  platform          :string           not null
#  notification_type :string           not null
#  sent_at           :datetime         not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  metadata          :json
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
