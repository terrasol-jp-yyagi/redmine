# frozen_string_literal: true

# Puma configuration for the container image.
# The port is taken from PORT / `rails server -p`, the bind address from `-b`.

max_threads = Integer(ENV.fetch('RAILS_MAX_THREADS', 5))
min_threads = Integer(ENV.fetch('RAILS_MIN_THREADS', max_threads))
threads min_threads, max_threads

worker_count = Integer(ENV.fetch('WEB_CONCURRENCY', 0))
if worker_count > 0
  workers worker_count
  preload_app!
end

environment ENV.fetch('RAILS_ENV', 'production')
