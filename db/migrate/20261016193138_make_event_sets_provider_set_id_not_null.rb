class MakeEventSetsProviderSetIdNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :event_sets, :provider_set_id, false
  end
end
