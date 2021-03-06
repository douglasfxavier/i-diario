Sidekiq.configure_server do |config|
  Sidekiq::Status.configure_server_middleware config, expiration: 7.days
  Sidekiq::Status.configure_client_middleware config, expiration: 7.days
end

Sidekiq.configure_client do |config|
  Sidekiq::Status.configure_server_middleware config, expiration: 7.days
  Sidekiq::Status.configure_client_middleware config, expiration: 7.days
end
