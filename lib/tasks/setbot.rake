namespace :setbot do

  task run: [:environment] do
    Setbot.run
  end

  task register_commands: [:environment] do
    Setbot.register_commands
  end

  task register_test_commands: [:environment] do
    Setbot.register_test_commands
  end

end
