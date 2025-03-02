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

  def self.log(notifiables, type:, platform:)
    notifiables = [notifiables] if !notifiables.is_a? Array

    puts "Attempting to send #{type} #{platform} notification for #{notifiables.count} #{notifiables.first.class.name.pluralize(notifiables.count)}"

    exception = nil
    begin
      yield
    rescue => e
      puts "Failed to send #{type} #{platform} notification for #{notifiables.count} #{notifiables.first.class.name.pluralize(notifiables.count)}: #{e.message}"
      exception = e
    end

    notifiables.each do |notifiable|
      create!(
        notifiable:,
        notification_type: type,
        platform:,
        success: exception.nil?,
        sent_at: Time.now
      )

      raise exception unless exception.nil?
    end
  end
end
