# iOS lanes: signing, build, TestFlight upload.
# Loaded from fastlane/Fastfile via import "./lanes/ios".

desc "Load ASC API Key information to use in subsequent lanes"
lane :load_asc_api_key do
  app_store_connect_api_key(
    key_id: ENV["ASC_KEY_ID"],
    issuer_id: ENV["ASC_ISSUER_ID"],
    key_content: ENV["ASC_KEY"],
    in_house: false
  )
end

desc "List Provisioning Profiles"
lane :list_profiles do
  sh "security find-identity -v -p codesigning"
end

# Shared: match, code signing setup, build_app. Call after version increment and load_asc_api_key.
private_lane :match_signing_build do
  require_relative "../match_allow_empty_password"
  # Use empty password when MATCH_PASSWORD is not set (works only if certs repo was created with empty passphrase).
  ENV["MATCH_PASSWORD"] = ENV["MATCH_PASSWORD"] || ""
  load_asc_api_key
  setup_ci
  match(
    type: 'appstore',
    readonly: false,
    verbose: true,
    force: true,
    git_basic_authorization: ENV["MATCH_GIT_BASIC_AUTHORIZATION"]
  )
  list_profiles
  sync_code_signing(
    type: "appstore",
    readonly: true
  )
  code_sign_identity = sh("security find-identity -v -p codesigning | grep 'Apple Distribution' | head -n 1 | awk -F '\"' '{print $2}'").strip
  # Use profile names set by match/sigh (they may have a suffix when preferred name is taken).
  main_profile = ENV["sigh_#{ENV['BUNDLE_IDENTIFIER']}_appstore_profile-name"] || "match AppStore #{ENV["BUNDLE_IDENTIFIER"]}"
  notifications_profile = ENV["sigh_#{ENV['BUNDLE_IDENTIFIER']}.notifications_appstore_profile-name"] || "match AppStore #{ENV["BUNDLE_IDENTIFIER"]}.notifications"
  # targets must be an array; string would result in no target matched.
  main_target = (ENV["XC_TARGET_NAME"].to_s.strip.empty? ? "BaseProject" : ENV["XC_TARGET_NAME"]).to_s
  update_code_signing_settings(
    use_automatic_signing: false,
    team_id: ENV["TEAM_ID"],
    targets: [main_target],
    code_sign_identity: code_sign_identity,
    sdk: "iphoneos*",
    profile_name: main_profile,
  )
  update_code_signing_settings(
    use_automatic_signing: false,
    team_id: ENV["TEAM_ID"],
    targets: ["notifications"],
    code_sign_identity: code_sign_identity,
    sdk: "iphoneos*",
    profile_name: notifications_profile,
  )
  build_app(
    scheme: ENV["XC_TARGET_NAME"],
    skip_build_archive: false,
    xcargs: "-allowProvisioningUpdates ASSETCATALOG_COMPILER_SKIP_APP_STORE_DEPLOYMENT=NO ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS=NO",
    sdk: "iphoneos",
    export_team_id: ENV["TEAM_ID"],
    verbose: true
  )
end

desc "Build for TestFlight (match, signing, build). Writes ipa_path.txt and build_number.txt for CI."
lane :build_for_testflight do
  major_version = ENV["MAJOR_VERSION"] || "1.0"
  last_uploaded_build = (ENV["LAST_UPLOADED_BUILD_NUMBER"] || "0").to_i
  new_minor = last_uploaded_build + 1
  new_build_number = "#{major_version}.#{new_minor}"
  increment_build_number(build_number: new_build_number)
  match_signing_build
  ipa_path = lane_context[SharedValues::IPA_OUTPUT_PATH]
  # Write to project root so CI "Prepare IPA for artifact" finds them (Fastlane CWD may be fastlane/).
  project_root = File.expand_path("..", FastlaneCore::FastlaneFolder.path)
  File.write(File.join(project_root, "ipa_path.txt"), ipa_path.to_s)
  File.write(File.join(project_root, "build_number.txt"), new_build_number)
  lane_context[:new_build_number] = new_build_number
end

desc "Upload IPA to TestFlight only. Pass ipa_path via option or ENV['IPA_PATH']."
lane :upload_testflight_only do |options|
  ipa_path = options[:ipa_path] || ENV["IPA_PATH"]
  UI.user_error!("IPA path required: set ipa_path option or IPA_PATH env") if ipa_path.to_s.empty?
  upload_to_testflight(
    ipa: ipa_path,
    apple_id: ENV["APPLE_APP_ID"],
    skip_waiting_for_build_processing: true
  )
  build_number = (File.read("build_number.txt") rescue nil)
  if build_number && ENV["GITHUB_ENV"]
    sh("echo 'LAST_UPLOADED_BUILD_NUMBER=#{build_number.strip}' >> $GITHUB_ENV")
  end
end

desc "Build and upload to TestFlight (full flow; can be used locally or as single job)."
lane :build_upload_testflight do
  build_for_testflight
  ipa_path = lane_context[SharedValues::IPA_OUTPUT_PATH]
  upload_testflight_only(ipa_path: ipa_path)
  new_build_number = lane_context[:new_build_number]
  sh("echo 'LAST_UPLOADED_BUILD_NUMBER=#{new_build_number}' >> $GITHUB_ENV") if new_build_number && ENV["GITHUB_ENV"]
end
