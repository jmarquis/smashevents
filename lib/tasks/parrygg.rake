namespace :parrygg do
  task :compile do
    sh 'rm -rf lib/parrygg/tmp'
    sh 'mkdir -p lib/parrygg/tmp'
    sh 'git clone https://github.com/parry-gg/protos lib/parrygg/tmp/protos'
    sh 'grpc_tools_ruby_protoc --proto_path=lib/parrygg/tmp/protos/src --ruby_out=lib/parrygg --grpc_out=lib/parrygg lib/parrygg/tmp/protos/src/**/*.proto'
    sh %[sed -i "s/require 'models\\//require_relative '..\\\/models\\\/\/g" lib/parrygg/**/*.rb]
    sh %[sed -i "s/require 'services\\//require_relative '..\\\/services\\\/\/g" lib/parrygg/**/*.rb]
    sh 'rm -rf lib/parrygg/tmp'
  end

  task sync: [:environment, 'parrygg:sync_tournaments', 'parrygg:sync_overrides', 'parrygg:sync_entrants']

  task sync_tournaments: [:environment] do
    Ingestor::Parrygg.sync_tournaments
  end

  task sync_overrides: [:environment] do
    Ingestor::Parrygg.sync_overrides
  end

  task sync_entrants: [:environemnt] do
    Ingestor::Parrygg.sync_entrants
  end

  task scan_sets: [:environment] do
  Ingestor::Parrygg.scan_sets
  end
end
