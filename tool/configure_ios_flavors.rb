#!/usr/bin/env ruby

require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == 'Runner' }
abort 'Runner target not found' unless runner

flavors = {
  'production' => {
    bundle_id: 'com.loyalo.loyalo',
    display_name: 'Loyalo',
  },
  'pilot' => {
    bundle_id: 'com.loyalo.loyalo.pilot',
    display_name: 'Loyalo Pilot',
  },
}

base_types = {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def clone_configuration(owner, source_name, destination_name, type)
  existing = owner.build_configurations.find { |config| config.name == destination_name }
  return existing if existing

  source = owner.build_configurations.find { |config| config.name == source_name }
  abort "Missing source configuration #{source_name}" unless source

  destination = owner.add_build_configuration(destination_name, type)
  destination.build_settings = source.build_settings.dup
  destination.base_configuration_reference = source.base_configuration_reference
  destination
end

base_types.each do |base_name, type|
  flavors.each_key do |flavor|
    clone_configuration(project, base_name, "#{base_name}-#{flavor}", type)
  end
end

project.targets.each do |target|
  base_types.each do |base_name, type|
    flavors.each do |flavor, settings|
      config = clone_configuration(
        target,
        base_name,
        "#{base_name}-#{flavor}",
        type,
      )
      next unless target.name == 'Runner'

      config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = settings[:bundle_id]
      config.build_settings['APP_DISPLAY_NAME'] = settings[:display_name]
      config.build_settings['FIREBASE_ENVIRONMENT'] = flavor
    end
  end
end

runner.build_configurations.each do |config|
  next if config.name.include?('-')

  config.build_settings['APP_DISPLAY_NAME'] = 'Loyalo Emulator'
  config.build_settings['FIREBASE_ENVIRONMENT'] = 'emulator'
end

runner.resources_build_phase.files.dup.each do |build_file|
  next unless build_file.file_ref&.path&.end_with?('GoogleService-Info.plist')

  build_file.remove_from_project
end

phase = runner.shell_script_build_phases.find do |candidate|
  candidate.name == 'Select Firebase configuration'
end
phase ||= runner.new_shell_script_build_phase('Select Firebase configuration')
phase.shell_path = '/bin/sh'
phase.input_paths = [
  '$(PROJECT_DIR)/Runner/GoogleService-Info.plist',
  '$(PROJECT_DIR)/config/pilot/GoogleService-Info.plist',
]
phase.output_paths = [
  '$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist',
]
phase.shell_script = <<~'SH'
  set -eu

  case "$FIREBASE_ENVIRONMENT" in
    production)
      SOURCE_PLIST="$PROJECT_DIR/Runner/GoogleService-Info.plist"
      EXPECTED_PROJECT="loyalo-app"
      ;;
    pilot)
      SOURCE_PLIST="$PROJECT_DIR/config/pilot/GoogleService-Info.plist"
      EXPECTED_PROJECT="loyalo-pilot"
      ;;
    emulator)
      # The default Runner scheme is reserved for isolated Emulator tests.
      # Dart/AppDelegate configure demo-loyalo-v2 explicitly, so no remote
      # GoogleService-Info.plist is bundled.
      exit 0
      ;;
    *)
      echo "error: FIREBASE_ENVIRONMENT must be production or pilot, got '$FIREBASE_ENVIRONMENT'" >&2
      exit 1
      ;;
  esac

  ACTUAL_PROJECT=$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' "$SOURCE_PLIST")
  if [ "$ACTUAL_PROJECT" != "$EXPECTED_PROJECT" ]; then
    echo "error: Firebase plist targets '$ACTUAL_PROJECT', expected '$EXPECTED_PROJECT'" >&2
    exit 1
  fi

  DESTINATION="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/GoogleService-Info.plist"
  mkdir -p "$(dirname "$DESTINATION")"
  cp "$SOURCE_PLIST" "$DESTINATION"
SH

runner.build_phases.delete(phase)
resources_index = runner.build_phases.index(runner.resources_build_phase)
runner.build_phases.insert(resources_index + 1, phase)

project.save
