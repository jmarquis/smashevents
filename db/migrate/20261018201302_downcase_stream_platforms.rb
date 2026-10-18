class DowncaseStreamPlatforms < ActiveRecord::Migration[8.1]
  def up
    execute 'UPDATE streams SET platform = LOWER(platform) WHERE platform IS NOT NULL'
  end

  def down
  end
end
