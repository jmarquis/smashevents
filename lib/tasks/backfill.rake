namespace :backfill do
  task event_completed_state: [:environment] do
    Event.find_each do |e|
      next if e.state.present?
      next if e.start_at.nil?
      next if e.start_at > 6.months.ago

      e.state = Event::STATE_COMPLETED
      e.save!
    end
  end
end
