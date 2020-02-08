#!/usr/bin/env ruby
#
# Script to extract information about a VyOS build from an ISO file
#

require 'fileutils'
require 'json'

if ARGV.count != 2
  $stderr.puts "Usage: make-build-info.rb <filename.iso> <filename.json>"
  exit(-1)
end

ISO_FILENAME, JSON_FILENAME = *ARGV
MNT_ISO = '/mnt/vyos-iso'
SQUASHFS_FILENAME = File.join(MNT_ISO, 'live/filesystem.squashfs')
MNT_SQUEEZEFS = '/mnt/vyos-squashfs'
VERSION_JSON_FILE = File.join(MNT_SQUEEZEFS, '/usr/share/vyos/version.json')

unless File.exist?(ISO_FILENAME)
  $stderr.puts "ISO file does not exist: #{ISO_FILENAME}"
  exit(-2)
end

# Create mount directories
FileUtils.mkdir_p(MNT_ISO) unless Dir.exist?(MNT_ISO)
FileUtils.mkdir_p(MNT_SQUEEZEFS) unless Dir.exist?(MNT_SQUEEZEFS)

# Unmount any previous mount
system('umount', '-q', MNT_SQUEEZEFS)
system('umount', '-q', MNT_ISO)


# Mount the ISO and SquashFS
system('mount', '-o', 'loop,ro', ISO_FILENAME, MNT_ISO) or raise "Failed to mount ISO"
system('mount', '-t', 'squashfs', '-o', 'loop,ro', SQUASHFS_FILENAME, MNT_SQUEEZEFS) or raise "Failed to mount SquashFS"

# Load the version information JSON file
build_data = JSON.parse(
	File.read(VERSION_JSON_FILE),
  {:symbolize_names => true}
)

# Get the Debian release version number
dv_filepath = File.join(MNT_SQUEEZEFS, '/etc/debian_version')
build_data[:debian_version] = File.read(dv_filepath).strip

# Get the Debian codename
osr_filepath = File.join(MNT_SQUEEZEFS, '/etc/os-release')
IO.popen(['bash', '-c', "source #{osr_filepath} && echo $VERSION_CODENAME"]) do |lines|
  build_data[:debian_codename] = lines.read.strip
end

# Get a list of installed debian packages
build_data[:packages] = {}
IO.popen(["chroot", MNT_SQUEEZEFS, 'dpkg-query', '--show', '-f', '${binary:Package}\t${Version}\n']) do |lines|
  lines.each do |line|
  	name, version = line.chomp.split(/\t/)
    build_data[:packages][name] = version
  end
end


# Unmount again
system('umount', MNT_SQUEEZEFS) or raise "Failed to unmount SquashFS"
system('umount', MNT_ISO) or raise "Failed to unmount ISO"


# Write the gathered data to JSON file
File.open(JSON_FILENAME, 'wb') do |file|
  file.write JSON.pretty_generate(build_data)
end
