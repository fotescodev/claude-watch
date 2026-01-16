---
module: ClaudeWatch
date: 2026-01-16
problem_type: build_error
component: testing_framework
symptoms:
  - "Build error: test target compiled for watchOS 10.0 but main module requires 10.6"
  - "Module compiled with incompatible deployment target"
  - "Tests fail to build while main app builds successfully"
root_cause: config_error
resolution_type: config_change
severity: high
tags: [xcode, deployment-target, watchos, test-target, project-config]
---

# Troubleshooting: Test Target Deployment Version Mismatch

## Problem
The project failed to build with an error indicating the test target was compiled for watchOS 10.0 while the main module required watchOS 10.6. This deployment target inconsistency prevented running tests.

## Environment
- Module: ClaudeWatch
- Platform: watchOS / Xcode
- Affected Component: ClaudeWatch.xcodeproj/project.pbxproj
- Date: 2026-01-16

## Symptoms
- Build error: "Module compiled for watchOS 10.0 cannot be imported by code compiled for watchOS 10.6"
- Test target fails to build while main app builds successfully
- Inconsistent WATCHOS_DEPLOYMENT_TARGET across targets in project.pbxproj
- Error appears when running tests or building test scheme

## What Didn't Work

**Direct solution:** The problem was identified and fixed on the first attempt after examining deployment targets in the project file.

## Solution

The test target had a different WATCHOS_DEPLOYMENT_TARGET than the main app target. All targets needed to be aligned to the same version.

**Configuration changes in project.pbxproj**:
```
// Before (broken):
// Main target
WATCHOS_DEPLOYMENT_TARGET = 10.6;

// Test target
WATCHOS_DEPLOYMENT_TARGET = 10.0;

// After (fixed):
// All targets aligned
WATCHOS_DEPLOYMENT_TARGET = 10.6;
```

**Steps to fix**:
1. Open project.pbxproj in text editor
2. Search for all occurrences of `WATCHOS_DEPLOYMENT_TARGET`
3. Update all values to `10.6` (or the highest required version)
4. Alternatively, in Xcode:
   - Select project in navigator
   - For each target, go to Build Settings
   - Search for "Deployment Target"
   - Set watchOS Deployment Target to 10.6

## Why This Works

1. **ROOT CAUSE**: When the main app's deployment target was updated to watchOS 10.6 (perhaps to use newer APIs), the test target's deployment target was not updated accordingly. Swift modules compiled with different deployment targets cannot be linked together.

2. **The solution** ensures all targets share the same deployment target:
   - Main app target: watchOS 10.6
   - Test target: watchOS 10.6
   - Any extension targets: watchOS 10.6

3. **Underlying issue**: Xcode does not automatically synchronize deployment targets across targets when one is changed. This is a common pitfall when updating minimum deployment versions.

## Prevention

- Use Xcode's project-level deployment target setting to ensure consistency
- Create a shared xcconfig file with deployment target:
  ```
  // Shared.xcconfig
  WATCHOS_DEPLOYMENT_TARGET = 10.6
  ```
- Add CI check that verifies all targets have matching deployment targets:
  ```bash
  grep -o 'WATCHOS_DEPLOYMENT_TARGET = [0-9.]*' project.pbxproj | sort -u | wc -l
  # Should output 1 (all same value)
  ```
- When updating deployment target, always check all targets in Build Settings
- Document minimum deployment target in README for the project

## Related Issues

No related issues documented yet.
