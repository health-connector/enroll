root_path = File.expand_path(File.join(File.dirname(__FILE__), ".."))

working_directory root_path
pid File.join(root_path, "tmp/pids/server.pid")

worker_processes ENV['SERVER_PROCESSES'] || 4
timeout ENV['SERVER_WORKER_TIMEOUT']&.to_i || 30
preload_app true

after_fork do |_server, _worker|
  Mongoid::Clients.clients.each do |_name, client|
    client.close
    client.reconnect
  end
  Acapi::Requestor.reconnect!
  Acapi::LocalAmqpPublisher.reconnect!
end

before_fork do |_server, _worker|
  Mongoid.disconnect_clients
end