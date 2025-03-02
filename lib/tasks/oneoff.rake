namespace :oneoff do

  task backfill_event_added_notifications: [:environment] do
    Event.where.not(notified_added_at: nil).each do |event|
      event_notification = event.notifications.find_by(
        notification_type: Notification::TYPE_EVENT_ADDED,
        platform: Notification::PLATFORM_DISCORD,
        success: true
      )

      if event_notification.blank?
        event.notifications.create!(
          notification_type: Notification::TYPE_EVENT_ADDED,
          platform: Notification::PLATFORM_DISCORD,
          success: true
        )
      end

      tournament_notification = event.tournament.notifications.find_by(
        notification_type: Notification::TYPE_TOURNAMENT_ADDED,
        platform: Notification::PLATFORM_TWITTER,
        success: true
      )

      if tournament_notification.blank?
        event.tournament.notifications.create!(
          notification_type: Notification::TYPE_TOURNAMENT_ADDED,
          platform: Notification::PLATFORM_TWITTER,
          success: true
        )
      end
    end
  end

end
