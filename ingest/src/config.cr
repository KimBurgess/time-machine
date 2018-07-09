# Application dependencies
require "action-controller"
require "active-model"
require "influxdb"

# Application code
require "./controllers/application"
require "./controllers/*"
require "./models/*"

# Server required after application controllers
require "action-controller/server"

# Add handlers that should run before your application
ActionController::Server.before(
  HTTP::LogHandler.new(STDOUT),
  HTTP::ErrorHandler.new(ENV["SG_ENV"]? != "production"),
  HTTP::CompressHandler.new
)

# Configure session cookies
# NOTE:: Change these from defaults
ActionController::Session.configure do
  settings.key = ENV["COOKIE_SESSION_KEY"]? || "_time_machine_"
  settings.secret = ENV["COOKIE_SESSION_SECRET"]? || "4f74c0b358d5bab4000dd3c75465dc2c"
end

APP_NAME = "Time Machine"
VERSION  = "1.0.0"
