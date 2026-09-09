# R8 was stripping androidx.work / Room's reflection-generated database
# implementation with no keep rules in place, crashing every release build
# on launch ("Failed to create an instance of androidx.work.impl.WorkDatabase")
# before Flutter ever got to run. See MainActivity crash, confirmed via a
# fresh install + cold launch of the release build.
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class * { *; }
-dontwarn androidx.work.**

# Play Core split-install classes referenced by Flutter's deferred-components
# support, not present at compile time for this app (no dynamic feature
# modules) — R8 warns without this even though nothing here uses them.
-dontwarn com.google.android.play.core.**
