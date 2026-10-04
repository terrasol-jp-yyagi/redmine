# This file is used by Rack-based servers to start the application.
# Container variant: honours RAILS_RELATIVE_URL_ROOT so Redmine can be served
# from a sub-URI (for example /redmine) without a rewriting reverse proxy.

require_relative 'config/environment'

relative_root = ENV['RAILS_RELATIVE_URL_ROOT'].to_s.strip
relative_root = '/' if relative_root.empty?

map relative_root do
  run Rails.application
end
