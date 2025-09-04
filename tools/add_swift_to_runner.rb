#!/usr/bin/env ruby
# Idempotently add macos/Runner/ScreenService.swift to the Runner target.
require 'xcodeproj'

proj_path = 'macos/Runner.xcodeproj'
swift_rel  = 'ScreenService.swift'     # path *inside* Runner group
group_path = 'Runner'                  # Xcode group (maps to macos/Runner on disk)
target_name = 'Runner'

project = Xcodeproj::Project.open(proj_path)

runner_target = project.targets.find { |t| t.name == target_name }
abort("Target '#{target_name}' not found") unless runner_target

runner_group = project.main_group.find_subpath(group_path, true)
runner_group.set_source_tree('<group>')

# Ensure the file exists on disk where the group points
disk_path = File.join('macos', group_path, swift_rel)
abort("File not found: #{disk_path}") unless File.exist?(disk_path)

# Reuse existing file reference if present (idempotent)
file_ref = runner_group.files.find { |f| f.path == swift_rel } || runner_group.new_file(swift_rel)

# Add to Sources build phase if missing (idempotent)
unless runner_target.source_build_phase.files_references.include?(file_ref)
  runner_target.add_file_references([file_ref])
end

project.save
puts "Added/ensured #{swift_rel} in target #{target_name}"