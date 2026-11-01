package io.github.hik4.todorbit

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** Runs the shared repository in a short-lived engine; no permanent service. */
class ReminderRefreshJob : JobService() {
    private var engine: FlutterEngine? = null
    private var active: JobParameters? = null
    private var authorization: BackgroundDriveAuthorization? = null
    private val handler=Handler(Looper.getMainLooper())
    private val timeout=Runnable {finish(true)}
    override fun onStartJob(params: JobParameters): Boolean {
        if(active!=null) return false
        active=params
        handler.postDelayed(timeout,45000)
        try {
            val loader=FlutterInjector.instance().flutterLoader()
            loader.startInitialization(this)
            // Engine resource extraction can be slow after an APK update. The
            // JobService callback must return promptly instead of blocking the
            // main thread while Flutter initializes.
            loader.ensureInitializationCompleteAsync(this,null,handler,Runnable {
                if(active !== params) return@Runnable
                try {
                    val worker=FlutterEngine(this); engine=worker
                    authorization=BackgroundDriveAuthorization(this)
                    MethodChannel(worker.dartExecutor.binaryMessenger,"todorbit/android").setMethodCallHandler {call,result ->
                        when(call.method) {
                            "dataRoot" -> result.success(filesDir.absolutePath)
                            "googleAuthorize" -> {
                                if(call.argument<Boolean>("interactive")==true) result.error("reconnect","Background authorization cannot open an account screen.",null)
                                else authorization?.authorize(call.argument<String>("account"),call.argument<Boolean>("force")==true,result)
                            }
                            "googleCancel" -> {authorization?.cancel();result.success(null)}
                            "reminderReceipts" -> result.success(AndroidSurfaces.reminderReceipts(this))
                            "publish" -> AndroidSurfaces.enqueue {
                                try {AndroidSurfaces.publish(this,call.arguments as String); result.success(null)}
                                catch (_: Exception) {result.error("refresh","Could not refresh Android surfaces",null)}
                            }
                            "backgroundComplete" -> {
                                val retry=call.argument<Boolean>("retry")==true
                                result.success(null); handler.post {finish(retry)}
                            }
                            else -> result.notImplemented()
                        }
                    }
                    val entry=if(params.jobId==2028 || params.jobId==2029) "androidSyncBackgroundMain" else "androidBackgroundMain"
                    worker.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(),entry))
                } catch (_: Exception) {finish(true)}
            })
            return true
        } catch (_: Exception) {finish(true); return false}
    }
    private fun finish(retry: Boolean) {
        handler.removeCallbacks(timeout)
        authorization?.cancel();authorization=null
        engine?.destroy(); engine=null
        active?.let {jobFinished(it,retry)}; active=null
    }
    override fun onStopJob(params: JobParameters): Boolean {handler.removeCallbacks(timeout); authorization?.cancel();authorization=null; engine?.destroy(); engine=null; active=null; return true}
    companion object {
        fun scheduleSync(context: Context, enabled: Boolean, immediate: Boolean=false) {
            val scheduler=context.getSystemService(JobScheduler::class.java)
            if(!enabled) {scheduler.cancel(2028);scheduler.cancel(2029);return}
            if(scheduler.getPendingJob(2028)==null) {
                scheduler.schedule(JobInfo.Builder(2028,ComponentName(context,ReminderRefreshJob::class.java))
                    .setPeriodic(JobInfo.getMinPeriodMillis()).setPersisted(true)
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setBackoffCriteria(30000,JobInfo.BACKOFF_POLICY_EXPONENTIAL).build())
            }
            if(immediate) scheduler.schedule(JobInfo.Builder(2029,ComponentName(context,ReminderRefreshJob::class.java))
                .setMinimumLatency(1000).setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setBackoffCriteria(30000,JobInfo.BACKOFF_POLICY_EXPONENTIAL).build())
        }
        fun schedule(context: Context, immediate: Boolean=false) {
            val scheduler=context.getSystemService(JobScheduler::class.java)
            val builder=JobInfo.Builder(if(immediate) 2027 else 2026,ComponentName(context,ReminderRefreshJob::class.java))
            if(immediate) builder.setMinimumLatency(1000).setOverrideDeadline(60000)
            else {if(scheduler.getPendingJob(2026)!=null) return; builder.setPeriodic(12L*60*60*1000).setPersisted(true)}
            scheduler.schedule(builder.build())
        }
    }
}
