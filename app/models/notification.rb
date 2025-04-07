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

class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true

  PLATFORM_TWITTER = 'twitter'
  PLATFORM_DISCORD = 'discord'

  TYPE_TOURNAMENT_ADDED = 'tournament_added'
  TYPE_EVENT_ADDED = 'event_added'
  TYPE_WEEKEND_BRIEFING = 'weekend_briefing'
  TYPE_CONGRATULATIONS = 'congratulations'
  TYPE_HAPPENING_TODAY = 'happening_today'
  TYPE_STREAM_LIVE = 'stream_live'
  TYPE_PLAYER_SET_LIVE = 'player_set_live'

  before_create do |notification|
    notification.sent_at ||= Time.now
  end

  def self.send_notification(notifiable_or_notifiables, type:, platform:, idempotent: false, metadata: nil)
    notifiables = notifiable_or_notifiables.is_a?(Array) ? notifiable_or_notifiables : [notifiable_or_notifiables]

    if idempotent
      notifiables.filter! do |notifiable|
        !Notification.exists?(
          notifiable:,
          notification_type: type,
          platform:,
          success: true
        )
      end
    end

    return unless notifiables.any?

    Rails.logger.info "Attempting to send #{type} #{platform} notification for #{notifiables.count} #{notifiables.first.class.name.pluralize(notifiables.count)}"

    exception = nil
    begin
      # Pass the singular notifiable since that's what the block will be
      # expecting if that's what was passed in. We will have short circuited by
      # now if needed regardless.
      yield(notifiable_or_notifiables.is_a?(Array) ? notifiables : notifiable_or_notifiables)
    rescue => e
      Rails.logger.error "Failed to send #{type} #{platform} notification for #{notifiables.count} #{notifiables.first.class.name.pluralize(notifiables.count)}: #{e.message}"
      exception = e
    end

    StatsD.increment("notification.#{platform}.#{type}.#{exception.nil? ? 'success' : 'failure'}")

    notifiables.each do |notifiable|
      create!(
        notifiable:,
        notification_type: type,
        platform:,
        success: exception.nil?,
        metadata:
      )
    end

    raise exception unless exception.nil?
  end
end
