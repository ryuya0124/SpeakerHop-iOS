# frozen_string_literal: true
require "bundler/setup"
require "fastlane"
require "fastlane_core/itunes_transporter"
abort "Run this command in your Mac terminal; never paste the password into chat." unless $stdin.tty?

user = ENV["FASTLANE_USER"] || FastlaneCore::UI.input("App Store Connect Apple Account:")
account = CredentialsManager::AccountManager.new(user: user,
  prefix: FastlaneCore::ItunesTransporter::TWO_STEP_HOST_PREFIX, note: "application-specific")
account.password(ask_if_missing: true)
FastlaneCore::UI.success("Upload credential saved in this Mac's keychain. No password was printed.")
