CarrierWave.configure do |config|
  config.storage = :grid_fs
  config.root = Rails.root.join('tmp')
  config.cache_dir = "uploads"
  config.grid_fs_access_url = "/tmp/uploads"
end