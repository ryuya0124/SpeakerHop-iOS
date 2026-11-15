# frozen_string_literal: true
# Preserve full license texts in the binary as well as the source repository.
root = File.expand_path("../..", __dir__)
native = File.join(root, "third_party/airplay2-sender-cpp")
files = [File.join(root, "LICENSE"), File.join(native, "NOTICE"),
  File.join(native, "licenses/THIRD-PARTY-NOTICES.txt"),
  File.join(native, "third_party/apple-alac/LICENSE"),
  File.join(native, "third_party/apple-alac/codec/APPLE_LICENSE.txt"),
  File.join(native, "third_party/ed25519/LICENSE.txt")]
text = files.map { |path| "#{File.basename(path)}\n#{'=' * 60}\n#{File.read(path)}" }.join("\n\n")
File.write(File.join(root, "ios/Sources/Acknowledgements.txt"), text)
File.write(File.join(root, "ios/Sources/PrivacyPolicy.txt"), File.read(File.join(root, "ios/appstore/privacy.md")))
