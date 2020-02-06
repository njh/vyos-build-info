#!/usr/bin/env ruby

require 'json'
require 'zlib'
require 'net/http'

VYOS_REPO_URL = "http://dev.packages.vyos.net/repositories/current"
PACKAGES_PATH = "/dists/current/main/binary-amd64/Packages.gz"

uri = URI.parse(VYOS_REPO_URL + PACKAGES_PATH)
$stderr.puts "Getting: #{uri}"

response = Net::HTTP.get_response(uri)
raise "Failed to fetch list of packages: #{response}" unless response.code == '200'

Zlib.gunzip(response.body).each_line do |line|
  if line.match(/^Package: (.+)$/)
    puts $1
  end
end
