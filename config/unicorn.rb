root_path = File.expand_path(File.join(File.dirname(__FILE__), ".."))
shared_path = File.expand_path(File.join(root_path, "..", "shared"))

working_directory root_path
pid shared_path + "/pids/unicorn.pid"
stderr_path shared_path + "/log/unicorn.log"
stdout_path shared_path + "/log/unicorn.log"

listen "/tmp/unicorn_enroll.ap.sock"
worker_processes 16
timeout 30
preload_app true

# Disconnect MongoDB clients before forking new worker processes
before_fork do |server, worker|
  Mongoid.disconnect_clients
end

# Close and reconnect MongoDB clients on worker boot
on_worker_boot do
  Mongoid::Clients.clients.each do |_name, client|
    client.close
    client.reconnect
  end
end

after_fork do |server, worker|
  Acapi::Requestor.reconnect!
  Acapi::LocalAmqpPublisher.reconnect!
end
