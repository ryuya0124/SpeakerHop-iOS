# frozen_string_literal: true
require "json"
require "open3"
require "fileutils"

def run(*args)
  out, err, status = Open3.capture3(*args)
  raise "#{args.first(3).join(' ')} failed: #{err[-500..]}" unless status.success?
  out
end

root = File.expand_path("..", __dir__)
app = File.join(root, "build/SimulatorData/Build/Products/Release-iphonesimulator/SpeakerHop.app")
raise "Build the simulator app through fastlane first" unless File.directory?(app)
runtime_list = JSON.parse(run("xcrun", "simctl", "list", "runtimes", "--json")).fetch("runtimes")
available = runtime_list.select { |r| r["isAvailable"] && r["identifier"].include?("iOS-") }
standard = available.reject { |r| r["identifier"].include?("iPhone19-4") }.max_by { |r| r["version"].split(".").map(&:to_i) }.fetch("identifier")
duo = available.find { |r| r["identifier"].include?("iPhone19-4") }&.fetch("identifier")
configs = [
  ["iPhone", "com.apple.CoreSimulator.SimDeviceType.iPhone-17", standard],
  ["iPad", "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB", standard],
  ["Duo", "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo", duo]
]

configs.each do |role, type, runtime|
  next unless runtime
  name = "SpeakerHop Layout #{role}"
  devices = JSON.parse(run("xcrun", "simctl", "list", "devices", "--json")).fetch("devices").values.flatten
  device = devices.find { |d| d["name"] == name && d["isAvailable"] }
  id = device ? device.fetch("udid") : run("xcrun", "simctl", "create", name, type, runtime).strip
  puts "Capturing #{role}, sequentially; audio sharing remains stopped."
  begin
    run("xcrun", "simctl", "boot", id) unless device && device["state"] == "Booted"
    run("xcrun", "simctl", "bootstatus", id, "-b")
    run("xcrun", "simctl", "install", id, app)
    run("xcrun", "simctl", "status_bar", id, "override", "--time", "9:41", "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3", "--batteryState", "charged", "--batteryLevel", "100")
    result = File.join(root, "build/layout-results", "#{role}.xcresult")
    attachments = File.join(root, "build/layout-results", "#{role}-attachments")
    FileUtils.rm_rf(result)
    FileUtils.rm_rf(attachments)
    run("bundle", "exec", "fastlane", "ios", "layout_test", "device:#{id}", "result:#{result}")
    run("xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", attachments)
    count = 0
    JSON.parse(File.read(File.join(attachments, "manifest.json"))).each do |test|
      test.fetch("attachments", []).each do |attachment|
        match = attachment["suggestedHumanReadableName"].to_s.match(/store_(ja|en-US)_(\d+)_(share|latency|diagnostics)/)
        next unless match
        dir = File.join(root, "build", role == "Duo" ? "duo-layouts" : "store-screenshots", match[1])
        FileUtils.mkdir_p(dir)
        FileUtils.cp(File.join(attachments, attachment.fetch("exportedFileName")), File.join(dir, "#{role}-#{match[2]}-#{match[3]}.png"))
        count += 1
      end
    end
    raise "Expected six verified #{role} screenshots, got #{count}" unless count == 6
  ensure
    # Only the explicitly named SpeakerHop simulators are stopped.
    run("xcrun", "simctl", "shutdown", id)
  end
end
