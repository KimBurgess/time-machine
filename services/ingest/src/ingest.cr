require "./ingest/*"
require "influxdb"

db_url = ENV["DATABASE_URL"]? || "http://localhost:8086"

puts "Connecting to db at #{db_url}"

client = InfluxDB::Client.new db_url, "", ""
db = client.databases["test_db"]

db.write "test_series", 123
