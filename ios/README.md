# Sprint Intervals (iPhone app)

Native version of the sprint interval timer in `../sprint/`. Unlike the web
version, its beeps and voice cues keep playing over Apple Music with the phone
locked or on silent.

## Install on your iPhone

1. Open `SprintIntervals.xcodeproj` in Xcode.
2. Click **SprintIntervals** at the top of the file list, then the
   **Signing & Capabilities** tab, and choose your Apple ID under **Team**.
   If Xcode says the bundle identifier is taken, change
   `com.gsccguardians.SprintIntervals` to something unique, e.g. add your initials.
3. Plug in your iPhone, pick it in the device menu at the top of the window,
   and press **Run** (▶).
4. First time only: on the iPhone open Settings → General →
   VPN & Device Management, tap your Apple ID and choose **Trust**.

With a free Apple ID the app stops opening after 7 days; press Run again to
reinstall it. Your settings and saved workouts are kept.
