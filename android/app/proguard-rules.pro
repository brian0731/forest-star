# WorkManager's Room database is created by reflection during AndroidX Startup,
# before Flutter runs. Its generated no-argument constructor must survive R8.
# The older Room runtime pulled in by the ads SDK does not preserve it in full mode.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
