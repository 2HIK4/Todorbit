package io.github.hik4.todorbit

import android.app.*
import android.content.*
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.*
import org.json.JSONObject
import androidx.core.app.NotificationCompat

/** Native scheduling/actions survive Flutter UI closure; never writes portable records. */
object AlarmDelivery {
    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)
    fun enabled(context: Context): Boolean = try {
        val pending=java.io.File(context.filesDir,"TodoPilot/pending-restore.json")
        val status=java.io.File(context.filesDir,"TodoPilot/restore-status.json")
        val file=java.io.File(context.filesDir,"TodoPilot/alarm-settings.json")
        !pending.exists() && (!status.exists() || JSONObject(status.readText()).optString("state")!="applied") &&
            (!file.exists() || JSONObject(file.readText()).let{it.getInt("version")==1 && it.getBoolean("enabled")})
    } catch(_:Exception){false}
    fun exact(context: Context) = Build.VERSION.SDK_INT < 31 ||
        context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    fun channel(context: Context, item: JSONObject): String {
        val sound = item.optString("sound", "alarm")
        val vibrate = item.optBoolean("vibrate", true)
        val id = "todorbit_alarm_${sound}_${if(vibrate) 1 else 0}"
        val type = when(sound) {"notification" -> RingtoneManager.TYPE_NOTIFICATION; "ringtone" -> RingtoneManager.TYPE_RINGTONE; else -> RingtoneManager.TYPE_ALARM}
        manager(context).createNotificationChannel(NotificationChannel(id, "Alarms · $sound${if(vibrate) " · vibration" else ""}", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Optional task and event alarms; sound stops automatically"
            setSound(RingtoneManager.getDefaultUri(type), AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
            enableVibration(vibrate)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        })
        return id
    }
    fun schedule(context: Context, item: JSONObject) {
        if(!enabled(context))return
        val key=item.getString("key")
        val prefs=AndroidSurfaces.preferences(context)
        val snooze=prefs.getLong("alarm-snooze-$key",0)
        val at=if(snooze>0) snooze else item.getLong("at")
        if(snooze==0L && AndroidSurfaces.delivered(context).contains(AndroidSurfaces.receipt(item))) return
        val now=System.currentTimeMillis()
        // Missed alarms have a five-minute grace; never ring arbitrary old backups.
        if(now-at>5*60*1000L) return
        val alarms=context.getSystemService(AlarmManager::class.java)
        val pending=AndroidSurfaces.alarmIntent(context,key)
        try {
            if(exact(context)) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,maxOf(at,now+1000),pending)
            else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,maxOf(at,now+1000),pending)
        } catch(_: SecurityException) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,maxOf(at,now+1000),pending)
        }
    }
    fun deliver(context: Context, item: JSONObject) {
        if(!enabled(context))return
        val key=item.getString("key"); val prefs=AndroidSurfaces.preferences(context)
        val snooze=prefs.getLong("alarm-snooze-$key",0)
        val due=if(snooze>0) snooze else item.getLong("at")
        val now=System.currentTimeMillis()
        if(due>now || now-due>5*60*1000L || !manager(context).areNotificationsEnabled()) return
        val receipt=AndroidSurfaces.receipt(item);val delivered=AndroidSurfaces.delivered(context)
        if(snooze==0L && delivered.contains(receipt)) return
        delivered.add(receipt)
        if(!prefs.edit().putLong("alarm-ringing-until-$key",now+item.optInt("durationSeconds",30).coerceIn(15,120)*1000L).remove("alarm-snooze-$key").putString("delivered-v2",org.json.JSONArray(delivered.toList().takeLast(1000)).toString()).commit()) return
        try {
            context.startForegroundService(Intent(context, AlarmSoundService::class.java).putExtra("item",item.toString()))
        } catch(_: RuntimeException) {
            // Inexact background fallback may not receive a foreground-service exemption.
            manager(context).notify(key,1,notification(context,item,false))
        }
    }
    private fun action(context: Context, item: JSONObject, minutes: Int): PendingIntent =
        PendingIntent.getBroadcast(context,0,Intent(context,AlarmActionReceiver::class.java)
            .setData(Uri.Builder().scheme("todorbit-alarm-action").authority("action").appendPath(item.getString("key")).appendQueryParameter("minutes",minutes.toString()).build()),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun openItem(context: Context,item: JSONObject): PendingIntent = PendingIntent.getActivity(context,0,
        Intent(context,MainActivity::class.java).setAction("todorbit-alarm-open").setData(Uri.parse(item.getString("link")))
            .putExtra("alarmKey",item.getString("key")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun notification(context: Context,item: JSONObject,silent: Boolean): Notification {
        val locked=AndroidSurfaces.privacy(context).optBoolean("enabled",true) && !AndroidSurfaces.foregroundUnlocked
        val remaining=if(item.has("startsAt")) Math.ceil((item.getLong("startsAt")-System.currentTimeMillis())/60000.0).toLong() else null
        val body=if(locked) "Open Todorbit to view details" else when {
            remaining==null -> item.optString("body")
            remaining>0 -> "${item.getString("title")} starts in $remaining minutes."
            remaining==0L -> "Scheduled start is now."
            else -> "Scheduled start was ${-remaining} minutes ago."
        }
        return NotificationCompat.Builder(context,channel(context,item))
            .setSmallIcon(R.drawable.ic_notification).setCategory(Notification.CATEGORY_ALARM)
            .setContentTitle(if(locked) "Todorbit alarm" else item.getString("title"))
            .setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(openItem(context,item))
            .setDeleteIntent(action(context,item,0)).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setTimeoutAfter(item.optInt("durationSeconds",30).coerceIn(15,120)*1000L)
            .setSilent(silent)
            .addAction(NotificationCompat.Action.Builder(0,"Dismiss",action(context,item,0)).build())
            .addAction(NotificationCompat.Action.Builder(0,"Snooze",action(context,item,-1)).build())
            .build()
    }
    fun current(context: Context,key: String): JSONObject? {
        if(!enabled(context))return null
        val plans=AndroidSurfaces.snapshot(context).optJSONArray("reminders") ?: return null
        return (0 until plans.length()).map{plans.getJSONObject(it)}.firstOrNull{it.optString("key")==key && it.optBoolean("alarm")}
    }
    fun act(context: Context,key: String,minutes: Int) {
        val item=current(context,key) ?: return
        AlarmSoundService.instance?.dismiss(key)
        manager(context).cancel(key,1)
        AndroidSurfaces.preferences(context).edit().remove("alarm-ringing-until-$key").commit()
        if(minutes in listOf(5,10,15)) {
            AndroidSurfaces.preferences(context).edit().putLong("alarm-snooze-$key",System.currentTimeMillis()+minutes*60_000L).commit()
            schedule(context,item)
        } else AndroidSurfaces.preferences(context).edit().remove("alarm-snooze-$key").commit()
    }
}

class AlarmActionReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) {
        val key=intent.data?.lastPathSegment ?: return
        val minutes=intent.data?.getQueryParameter("minutes")?.toIntOrNull() ?: return
        if(minutes == -1) {
            // An activity PendingIntent is needed for a chooser on modern Android;
            // three direct actions avoid a background activity launch.
            AlarmDelivery.current(context,key)?.let { item ->
                AlarmSoundService.instance?.dismiss(key)
                val choices=NotificationCompat.Builder(context,AlarmDelivery.channel(context,item))
                    .setSmallIcon(R.drawable.ic_notification).setContentTitle("Snooze alarm")
                    .setContentText("Choose 5, 10 or 15 minutes").setSilent(true)
                    .setDeleteIntent(PendingIntent.getBroadcast(context,0,Intent(context,AlarmActionReceiver::class.java)
                        .setData(Uri.parse("todorbit-alarm-action://action/${Uri.encode(key)}?minutes=0")),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                for(n in listOf(5,10,15)) choices.addAction(NotificationCompat.Action.Builder(0,"$n min",
                    PendingIntent.getBroadcast(context,0,Intent(context,AlarmActionReceiver::class.java)
                        .setData(Uri.parse("todorbit-alarm-action://action/${Uri.encode(key)}?minutes=$n")),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)).build())
                context.getSystemService(NotificationManager::class.java).notify(key,1,choices.build())
            }
        } else AlarmDelivery.act(context,key,minutes)
    }
}

/** One short-lived native service, one audio player; no permanent polling. */
class AlarmSoundService: Service() {
    companion object {
        var instance: AlarmSoundService?=null
            private set
    }
    private val handler=Handler(Looper.getMainLooper())
    private val active=linkedMapOf<String,JSONObject>()
    private var player: MediaPlayer?=null
    private var vibrator: Vibrator?=null
    private val monitor=object:Runnable {
        override fun run() {
            if(active.isEmpty())return
            val manager=getSystemService(NotificationManager::class.java)
            val privacy=AndroidSurfaces.privacy(this@AlarmSoundService)
            val hidden=privacy.optBoolean("enabled",true) && privacy.optBoolean("hideNotifications",true) && !AndroidSurfaces.foregroundUnlocked
            val channel=manager.getNotificationChannel(AlarmDelivery.channel(this@AlarmSoundService,active.values.last()))
            if(!AlarmDelivery.enabled(this@AlarmSoundService) || hidden || !manager.areNotificationsEnabled() || channel.importance<NotificationManager.IMPORTANCE_DEFAULT || channel.sound==null ||
                manager.currentInterruptionFilter !in listOf(NotificationManager.INTERRUPTION_FILTER_ALL,NotificationManager.INTERRUPTION_FILTER_ALARMS)) {
                for(key in active.keys.toList())dismiss(key)
                return
            }
            handler.postDelayed(this,1000)
        }
    }
    override fun onBind(intent: Intent?) = null
    override fun onCreate(){super.onCreate();instance=this}
    override fun onStartCommand(intent: Intent?,flags: Int,startId: Int): Int {
        val raw=intent?.getStringExtra("item") ?: run {stopSelf();return START_NOT_STICKY}
        val item=JSONObject(raw);val key=item.getString("key")
        if(AlarmDelivery.current(this,key)==null){stopSelf();return START_NOT_STICKY}
        if(active.containsKey(key)) return START_NOT_STICKY
        active[key]=item
        if(active.size==1)handler.postDelayed(monitor,1000)
        startForeground(9001,AlarmDelivery.notification(this,item,true))
        play(item)
        handler.postDelayed({dismiss(key)},item.optInt("durationSeconds",30).coerceIn(15,120)*1000L)
        return START_NOT_STICKY
    }
    private fun play(item: JSONObject) {
        player?.release();player=null;vibrator?.cancel()
        val manager=getSystemService(NotificationManager::class.java)
        val channel=manager.getNotificationChannel(AlarmDelivery.channel(this,item))
        if(!manager.areNotificationsEnabled() || channel.importance<NotificationManager.IMPORTANCE_DEFAULT ||
            channel.sound==null || manager.currentInterruptionFilter !in listOf(NotificationManager.INTERRUPTION_FILTER_ALL,NotificationManager.INTERRUPTION_FILTER_ALARMS))return
        try {
            player=MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                setWakeMode(this@AlarmSoundService,PowerManager.PARTIAL_WAKE_LOCK)
                setDataSource(this@AlarmSoundService,channel.sound);isLooping=true;prepare();start()
            }
            if(item.optBoolean("vibrate",true) && channel.shouldVibrate()) {
                vibrator=if(Build.VERSION.SDK_INT>=31)getSystemService(VibratorManager::class.java).defaultVibrator else getSystemService(Vibrator::class.java)
                vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0,500,500),0))
            }
        } catch(_: Exception){player?.release();player=null}
    }
    fun reconcile() {handler.post {
        for(key in active.keys.toList()) if(AlarmDelivery.current(this,key)==null) dismiss(key)
    }}
    fun dismiss(key: String) {
        if(active.remove(key)==null)return
        AndroidSurfaces.preferences(this).edit().remove("alarm-ringing-until-$key").commit()
        getSystemService(NotificationManager::class.java).cancel(key,1)
        if(active.isEmpty()) {stopForeground(STOP_FOREGROUND_REMOVE);stopSelf()}
        else {val item=active.values.last();startForeground(9001,AlarmDelivery.notification(this,item,true));play(item)}
    }
    override fun onDestroy(){handler.removeCallbacksAndMessages(null);player?.release();vibrator?.cancel();instance=null;super.onDestroy()}
}
