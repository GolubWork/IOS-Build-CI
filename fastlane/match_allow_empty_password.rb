# Monkey-patch Match to allow empty MATCH_PASSWORD (certs repo created with empty passphrase).
# Match gem raises "No password supplied" in encrypt_specific_file when password.to_s.strip.empty?
# We allow empty string so CI can run without MATCH_PASSWORD secret.

return if defined?(Match::Encryption::OpenSSL::ALLOW_EMPTY_PASSWORD_PATCHED)

# Load Match::Encryption::OpenSSL if not yet loaded (e.g. before first match() call).
unless defined?(Match::Encryption::OpenSSL)
  begin
    fastlane_spec = Gem.loaded_specs["fastlane"]
    path = File.join(fastlane_spec.full_gem_path, "match", "lib", "match", "encryption", "openssl.rb")
    require path
  rescue StandardError
    # Match may get loaded later when match() runs; patch will apply on next require.
    nil
  end
end

if defined?(Match::Encryption::OpenSSL)
  Match::Encryption::OpenSSL.class_eval do
    def encrypt_specific_file(path: nil, password: nil, version: nil)
      # Only reject nil; allow empty string (repo encrypted with empty passphrase).
      UI.user_error!("No password supplied") if password.nil?
      e = Match::Encryption::MatchFileEncryption.new
      e.encrypt(file_path: path, password: password, version: version)
    rescue FastlaneCore::Interface::FastlaneError
      raise
    rescue StandardError => error
      UI.error(error.to_s)
      UI.crash!("Error encrypting '#{path}'")
    end
  end
  Match::Encryption::OpenSSL.const_set(:ALLOW_EMPTY_PASSWORD_PATCHED, true)
end
