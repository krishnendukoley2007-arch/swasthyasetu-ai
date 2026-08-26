## Description
<!-- Briefly describe the changes and why they're needed -->


## Type of Change
<!-- Check all that apply -->
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix/feature that changes existing behavior)
- [ ] Refactor (code restructuring without behavior change)
- [ ] Documentation update
- [ ] Test improvement
- [ ] Build/CI configuration
- [ ] Dependency update

## Related Issues
<!-- Link issues this PR addresses -->
Closes #
Related to #

## Testing
<!-- Describe how you tested this -->
- [ ] Unit tests pass (`flutter test` in `app/`)
- [ ] Integration tests pass (if applicable)
- [ ] Manual testing on device/emulator
- [ ] Tested offline mode
- [ ] Tested with sensor board (if BLE changes)
- [ ] Tested demo mode

## Screenshots / Recordings
<!-- Before/after screenshots or screen recordings for UI changes -->


## Checklist
<!-- All items must be checked before merge -->
- [ ] `flutter analyze` passes (no new warnings/errors)
- [ ] `flutter test` passes (all 428+ tests)
- [ ] Code follows project conventions (Dart style, Riverpod patterns)
- [ ] No hardcoded strings — all UI text in `.arb` files
- [ ] No fabricated values — missing data renders as `—`
- [ ] Provenance maintained — demo data never becomes measured data
- [ ] Permissions handled gracefully (optional, degradable)
- [ ] Offline-first — feature works without network
- [ ] Documentation updated (README, comments, ARB files if new strings)
- [ ] Migration steps noted (if DB schema changed)

## Breaking Changes
<!-- If this is a breaking change, describe migration path -->


## Additional Notes
<!-- Any other context for reviewers -->