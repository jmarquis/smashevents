namespace :setbot do

  task run: [:environment] do
    Setbot.run
  end

end
