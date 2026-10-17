namespace :metrics do
  task report_model_stats: [:environment] do
    ApplicationRecord.descendants.each do |model|
      StatsD.gauge("model_counts.#{model.table_name}", model.count)
    end
  end
end
