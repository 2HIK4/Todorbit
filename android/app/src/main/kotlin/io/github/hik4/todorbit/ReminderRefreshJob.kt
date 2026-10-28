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
    private val handler=Handler(Looper.getMainLooper())
    private val timeout=Runnable {finish(true)}
    override fun onStartJob(params: JobParameters): Boolean {
        if(engine!=null) return false
        active=params
        try {
            val loader=FlutterInjector.instance().flutterLoader()
            loader.startInitialization(this); loader.ensureInitializationComplete(this,null)
            val worker=FlutterEngine(this); engine=worker
            MethodChannel(worker.dartExecutor.binaryMessenger,"todorbit/android").setMethodCallHandler {call,result ->
                when(call.method) {
                    "dataRoot" -> result.success(filesDir.absolutePath)
                    "publish" -> try {AndroidSurfaces.publish(this,call.arguments as String); result.success(null)}
                        catch (_: Exception) {result.error("refresh","Could not refresh Android surfaces",null)}
                    "backgroundComplete" -> {result.success(null); handler.post {finish(false)}}
                    else -> result.notImplemented()
                }
            }
            worker.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(),"androidBackgroundMain"))
            handler.postDelayed(timeout,45000)
            return true
        } catch (_: Exception) {finish(true); return false}
    }
    private fun finish(retry: Boolean) {
        handler.removeCallbacks(timeout)
        engine?.destroy(); engine=null
        active?.let {jobFinished(it,retry)}; active=null
    }
    override fun onStopJob(params: JobParameters): Boolean {handler.removeCallbacks(timeout); engine?.destroy(); engine=null; active=null; return true}
    companion object {
        fun schedule(context: Context, immediate: Boolean=false) {
            val scheduler=context.getSystemService(JobScheduler::class.java)
            val builder=JobInfo.Builder(if(immediate) 2027 else 2026,ComponentName(context,ReminderRefreshJob::class.java))
            if(immediate) builder.setMinimumLatency(1000).setOverrideDeadline(60000)
            else {if(scheduler.getPendingJob(2026)!=null) return; builder.setPeriodic(12L*60*60*1000).setPersisted(true)}
            scheduler.schedule(builder.build())
        }
    }
}
