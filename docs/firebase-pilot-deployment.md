# Firebase Pilot deployment runbook

Target project: `loyalo-pilot` only.

This runbook prepares step 5C.4-B. It must not be executed until billing,
services and the final change review have been approved.

## Mandatory preflight

```bash
test "$(jq -r '.projects.pilot' .firebaserc)" = "loyalo-pilot"
test "$(jq -r '.project_info.project_id' android/app/src/pilot/google-services.json)" = "loyalo-pilot"
test "$(plutil -extract PROJECT_ID raw ios/config/pilot/GoogleService-Info.plist)" = "loyalo-pilot"
firebase projects:list --json | jq -e '.result[] | select(.projectId == "loyalo-pilot" and .state == "ACTIVE")'
firebase apps:list --project loyalo-pilot --json
```

Before deploying Functions, manually verify that `loyalo-pilot` is on the
Blaze plan and that the Cloud Functions, Cloud Build, Artifact Registry,
Cloud Run and Eventarc APIs required by Functions v2 are enabled.

All backend validation and Functions deployment commands must run with the
declared Node.js 24 runtime:

```bash
env PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin" \
  node --version | grep '^v24\.'
```

## Local validation

```bash
flutter analyze
flutter test
env PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin" \
  npm --prefix functions test
env PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin" \
  npm --prefix functions run lint
env PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin" \
  JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  firebase emulators:exec --project demo-loyalo-v2 \
  --only auth,firestore,functions,storage \
  "npm --prefix functions run test:emulator"
git diff --check
```

## Controlled deployment commands

Run each command separately and re-run the preflight guard before it.

```bash
test "$(jq -r '.projects.pilot' .firebaserc)" = "loyalo-pilot" && \
  firebase deploy --project loyalo-pilot --config firebase.pilot.json \
  --only firestore:indexes

test "$(jq -r '.projects.pilot' .firebaserc)" = "loyalo-pilot" && \
  env PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin" \
  firebase deploy --project loyalo-pilot --config firebase.pilot.json \
  --only functions:approveCheckInSecure,functions:rejectCheckInSecure,functions:sendPushForNotification

test "$(jq -r '.projects.pilot' .firebaserc)" = "loyalo-pilot" && \
  firebase deploy --project loyalo-pilot --config firebase.pilot.json \
  --only firestore:rules

test "$(jq -r '.projects.pilot' .firebaserc)" = "loyalo-pilot" && \
  firebase deploy --project loyalo-pilot --config firebase.pilot.json \
  --only storage
```

Never add `--force` to the index deployment without reviewing every proposed
remote index deletion.

## Post-deployment checks

```bash
firebase functions:list --project loyalo-pilot
firebase firestore:indexes --project loyalo-pilot
```

Then execute the native Pilot integration test against test accounts only.
Do not use production credentials or data.

## Rollback

Before 5C.4-B, create a reviewed Git snapshot of the exact Pilot rules,
indexes, Storage rules and Functions sources. Keep the previously deployed
snapshot separately.

- Rules and Storage: redeploy the previous reviewed snapshot with the same
  explicit `--project loyalo-pilot --config firebase.pilot.json` arguments.
- Functions: redeploy the previous backend snapshot. If a v2 revision is
  unhealthy, stop Pilot traffic while the previous revision is restored.
- Indexes: do not delete an existing index during emergency rollback. Restore
  missing indexes from the previous manifest and wait until they are ready.
- Mobile: disable Pilot distribution or ship the previous Pilot build. Never
  point a Pilot build to `loyalo-app` as a rollback mechanism.
