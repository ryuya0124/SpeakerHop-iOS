# frozen_string_literal: true
require "json"
require "open3"
require "fileutils"

def run(*args)
  out, err, status = Open3.capture3(*args)
  raise "#{args.first(3).join(' ')} failed: #{err[-500,500]}" unless status.success?
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
    %w[ja en-US].each do |locale|
      language = locale == "ja" ? "ja" : "en"
      begin
        run("xcrun", "simctl", "terminate", id, "dev.ryuya.speakerhop")
      rescue StandardError
        # A previously unlaunched app has nothing to terminate.
      end
      run("xcrun", "simctl", "launch", id, "dev.ryuya.speakerhop", "-AppleLanguages", "(#{language})", "-AppleLocale", locale)
      dir = File.join(root, "build", role == "Duo" ? "duo-layouts" : "store-screenshots", locale)
      FileUtils.mkdir_p(dir)
      %w[share latency diagnostics].each_with_index do |page, i|
        run("xcrun", "simctl", "openurl", id, "speakerhop://#{page}")
        # Allow the navigation animation to settle; image inspection is still mandatory afterward.
        sleep 1
        run("xcrun", "simctl", "io", id, "screenshot", File.join(dir, "#{role}-#{i+1}-#{page}.png"))
      end
    end
  ensure
    # Only the explicitly named SpeakerHop simulators are stopped.
    run("xcrun", "simctl", "shutdown", id)
  end
end
