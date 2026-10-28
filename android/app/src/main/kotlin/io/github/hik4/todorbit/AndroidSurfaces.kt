package io.github.hik4.todorbit

import android.app.*
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.*
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.*
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.ZoneId
import java.io.File
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/** Read-only projections from the shared Dart repository; never opens SQLite. */
object AndroidSurfaces {
    const val channelId = "todorbit_reminders"
    // Process-local: a crashed/killed app never leaves a persisted unlock grant.
    var foregroundUnlocked = false
    fun preferences(context: Context) = context.getSharedPreferences("android-surfaces-v1", Context.MODE_PRIVATE)
    fun snapshot(context: Context): JSONObject = try { JSONObject(preferences(context).getString("snapshot", "{}")!!) } catch (_: Exception) { JSONObject() }
    fun receipt(item: JSONObject): String {
        val key=item.getString("key")
        return if(key.startsWith("due:") || key.startsWith("summary:")) key
            else key + ":" + item.optLong("occurrenceAt",item.getLong("at"))
    }
    fun delivered(context: Context): LinkedHashSet<String> {
        val prefs = preferences(context)
        val ordered = prefs.getString("delivered-v2", null)
        if (ordered == null) return LinkedHashSet(prefs.getStringSet("delivered", emptySet())!!)
        // Keep insertion order when pruning, so old receipts cannot evict a
        // recent delivery and allow the next refresh to notify it twice.
        val list = JSONArray(ordered)
        return LinkedHashSet((0 until list.length()).map { list.getString(it) })
    }
    fun privacy(context: Context): JSONObject = try {
        val file=File(context.filesDir,"TodoPilot/privacy-settings.json")
        if(file.exists()) JSONObject(file.readText()) else JSONObject().put("enabled",false)
    } catch (_: Exception) {JSONObject().put("enabled",true).put("hideNotifications",true)}
    fun reminderReceipts(context: Context): Map<String, List<String>> {
        val plans=snapshot(context).optJSONArray("reminders") ?: JSONArray()
        return mapOf("pending" to (0 until plans.length()).map {receipt(plans.getJSONObject(it))},
            "delivered" to delivered(context).toList())
    }
    fun publish(context: Context, source: String) {
        val next = JSONObject(source)
        require(next.getInt("version") == 1)
        val old = snapshot(context).optJSONArray("reminders") ?: JSONArray()
        // Commit first: receivers reject obsolete alarms even if cancellation races.
        check(preferences(context).edit().putString("snapshot", source).commit())
        val alarms = context.getSystemService(AlarmManager::class.java)
        for(i in 0 until old.length()) alarms.cancel(alarmIntent(context, old.getJSONObject(i).getString("key")))
        scheduleReminders(context)
        updateWidgets(context)
        scheduleRefresh(context)
    }
    fun alarmIntent(context: Context, key: String): PendingIntent = PendingIntent.getBroadcast(context,0,
        Intent(context, ReminderReceiver::class.java).setAction("reminder")
            .setData(Uri.Builder().scheme("todorbit-alarm").authority("reminder").appendPath(key).build()),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun scheduleReminders(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(channelId, "Task and event reminders", NotificationManager.IMPORTANCE_DEFAULT)
            .apply { description = "Reminders explicitly enabled in Todorbit" })
        val alarms = context.getSystemService(AlarmManager::class.java)
        val plans = snapshot(context).optJSONArray("reminders") ?: JSONArray()
        val receipts = delivered(context)
        for(i in 0 until plans.length()) {
            val item = plans.getJSONObject(i)
            val receipt = receipt(item)
            val now=System.currentTimeMillis()
            if(now-item.getLong("at") < 24L*60*60*1000 && !receipts.contains(receipt))
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,maxOf(item.getLong("at"),now+1000),alarmIntent(context,item.getString("key")))
        }
    }
    fun open(context: Context, link: String): PendingIntent = PendingIntent.getActivity(context,0,
        Intent(context, MainActivity::class.java).setAction(Intent.ACTION_VIEW).setData(Uri.parse(link))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun updateWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for(cls in listOf(TasksWidget::class.java, CalendarWidget::class.java))
            for(id in manager.getAppWidgetIds(ComponentName(context,cls))) render(context,manager,id,cls == CalendarWidget::class.java)
    }
    fun scheduleRefresh(context: Context) {
        val midnight = ZonedDateTime.now().toLocalDate().plusDays(1).atStartOfDay(ZonedDateTime.now().zone).toInstant().toEpochMilli()
        val intent = PendingIntent.getBroadcast(context,0,Intent(context, SurfaceRefreshReceiver::class.java).setAction("midnight"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        context.getSystemService(AlarmManager::class.java).set(AlarmManager.RTC,midnight,intent)
    }
    fun render(context: Context, manager: AppWidgetManager, id: Int, calendar: Boolean) {
        val prefs = preferences(context)
        val data = snapshot(context)
        val theme = prefs.getString("theme-$id","system")
        val dark = theme == "dark" || theme == "system" && (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val foreground = if(dark) Color.rgb(244,240,252) else Color.rgb(33,27,53)
        val background = if(dark) Color.rgb(37,33,49) else Color.WHITE
        val opacity = prefs.getInt("opacity-$id", 95)
        val remote = RemoteViews(context.packageName,R.layout.todorbit_widget)
        remote.setInt(R.id.widget_root,"setBackgroundColor",Color.argb(opacity * 255 / 100,Color.red(background),Color.green(background),Color.blue(background)))
        remote.setTextColor(R.id.widget_title,foreground)
        val today = LocalDate.now().toString()
        remote.setTextViewText(R.id.widget_title,if(calendar) "Todorbit · ${LocalDate.now().format(DateTimeFormatter.ofPattern("MMM d"))}" else "Todorbit Tasks")
        remote.setOnClickPendingIntent(R.id.widget_title,open(context,"todorbit://${if(calendar) "calendar" else "tasks"}?day=$today"))
        remote.setOnClickPendingIntent(R.id.widget_add,open(context,"todorbit://add"))
        remote.setTextColor(R.id.widget_add,foreground)
        remote.removeAllViews(R.id.widget_rows)
        val hidden = privacy(context).optBoolean("enabled",true) || data.optBoolean("private", true)
        val source = data.optJSONArray(if(calendar) "agenda" else "tasks") ?: JSONArray()
        val filter = prefs.getString("filter-$id","today")
        val options = manager.getAppWidgetOptions(id)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,180)
        val rowHeight = kotlin.math.ceil(48 * context.resources.configuration.fontScale + 12.0).toInt()
        val capacity = ((height-72)/rowHeight).coerceIn(0,10)
        var count = 0
        if(!hidden) for(i in 0 until source.length()) {
            val item = source.getJSONObject(i)
            val eligible = if(calendar) item.optLong("until",0L) > LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                else when(filter) {"inbox" -> item.optBoolean("inbox"); "all" -> true; else -> item.optString("day") == today}
            if(!eligible || count >= capacity) continue
            val row = RemoteViews(context.packageName,R.layout.todorbit_widget_row)
            row.setTextViewText(R.id.widget_row_title,item.getString("title"))
            row.setTextViewText(R.id.widget_row_detail,if(calendar) item.optString("detail") else if(item.optBoolean("done")) "Completed" else item.optString("detail"))
            row.setTextColor(R.id.widget_row_title,foreground); row.setTextColor(R.id.widget_row_detail,foreground)
            row.setOnClickPendingIntent(R.id.widget_row,open(context,item.getString("link")))
            remote.addView(R.id.widget_rows,row); count++
        }
        remote.setViewVisibility(R.id.widget_empty,if(count == 0) View.VISIBLE else View.GONE)
        remote.setTextColor(R.id.widget_empty,foreground)
        remote.setTextViewText(R.id.widget_empty,if(capacity == 0) "Resize widget" else if(hidden) "Details hidden by app lock. Open Todorbit." else "No items. Open Todorbit to refresh.")
        remote.setOnClickPendingIntent(R.id.widget_empty,open(context,"todorbit://${if(calendar) "calendar" else "tasks"}?day=$today"))
        manager.updateAppWidget(id,remote)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val key = intent.data?.lastPathSegment ?: return
        val data = AndroidSurfaces.snapshot(context)
        val policy=AndroidSurfaces.privacy(context)
        val locked=policy.optBoolean("enabled",true) && !AndroidSurfaces.foregroundUnlocked
        if(locked && policy.optBoolean("hideNotifications",true)) return
        val plans = data.optJSONArray("reminders") ?: return
        val item = (0 until plans.length()).map {plans.getJSONObject(it)}.firstOrNull {it.optString("key") == key} ?: return
        val at = item.getLong("at")
        if(at > System.currentTimeMillis() || System.currentTimeMillis()-at > 24L*60*60*1000) return
        // Recheck at delivery: Doze may have delayed an earlier alarm into quiet hours.
        try {
            val file=File(context.filesDir,"TodoPilot/mobile-preferences.json")
            val settings=if(file.exists()) JSONObject(file.readText()) else JSONObject()
            if(settings.optBoolean("quietHours",false)) {
                val start=settings.optInt("quietStart",1320); val end=settings.optInt("quietEnd",420)
                val now=ZonedDateTime.now(); val minute=now.hour*60+now.minute
                val overnight=start>end
                val quiet=start!=end && if(overnight) minute>=start || minute<end else minute>=start && minute<end
                if(quiet) {
                    val date=now.toLocalDate().plusDays(if(overnight && minute>=start) 1 else 0)
                    val later=date.atTime(end/60,end%60).atZone(now.zone).toInstant().toEpochMilli()
                    context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,later,AndroidSurfaces.alarmIntent(context,key))
                    return
                }
            }
        } catch (_: Exception) { return }
        val prefs = AndroidSurfaces.preferences(context)
        val receipts = AndroidSurfaces.delivered(context)
        val receipt = AndroidSurfaces.receipt(item)
        if(receipts.contains(receipt)) return
        if(!context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()) return
        val hidden = locked
        val notification = Notification.Builder(context,AndroidSurfaces.channelId).setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(if(hidden) "Todorbit reminder" else item.getString("title"))
            .setContentText(if(hidden) "Open Todorbit to view details" else item.optString("body","Open to view details"))
            .setContentIntent(AndroidSurfaces.open(context,item.getString("link"))).setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE).build()
        try {
            context.getSystemService(NotificationManager::class.java).notify(key,0,notification)
            receipts.add(receipt)
            prefs.edit().putString("delivered-v2",JSONArray(receipts.toList().takeLast(1000)).toString()).remove("delivered").apply()
            ReminderRefreshJob.schedule(context,true)
        } catch (_: SecurityException) { /* Permission was revoked after planning. */ }
    }
}

class SurfaceRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AndroidSurfaces.scheduleReminders(context)
        AndroidSurfaces.updateWidgets(context)
        AndroidSurfaces.scheduleRefresh(context)
        ReminderRefreshJob.schedule(context)
        ReminderRefreshJob.schedule(context,true)
    }
}

class TasksWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { for(id in ids) AndroidSurfaces.render(context,manager,id,false) }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) { AndroidSurfaces.render(context,manager,id,false) }
    override fun onDeleted(context: Context, ids: IntArray) { for(id in ids) AndroidSurfaces.preferences(context).edit().remove("theme-$id").remove("filter-$id").remove("opacity-$id").apply() }
}
class CalendarWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { for(id in ids) AndroidSurfaces.render(context,manager,id,true) }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) { AndroidSurfaces.render(context,manager,id,true) }
    override fun onDeleted(context: Context, ids: IntArray) { for(id in ids) AndroidSurfaces.preferences(context).edit().remove("theme-$id").remove("filter-$id").remove("opacity-$id").apply() }
}

class WidgetConfigurationActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,AppWidgetManager.INVALID_APPWIDGET_ID)
        if(id == AppWidgetManager.INVALID_APPWIDGET_ID) {finish(); return}
        val prefs = AndroidSurfaces.preferences(this)
        val calendar=AppWidgetManager.getInstance(this).getAppWidgetInfo(id)?.provider?.className == CalendarWidget::class.java.name
        val layout = LinearLayout(this).apply {orientation=LinearLayout.VERTICAL; setPadding(32,48,32,32)}
        fun label(text: String) {layout.addView(TextView(this).apply {this.text=text; textSize=18f; setPadding(0,24,0,12)})}
        fun spinner(values: Array<String>, selected: String): Spinner = Spinner(this).also { s ->
            s.adapter=ArrayAdapter(this,android.R.layout.simple_spinner_dropdown_item,values)
            s.setSelection(values.indexOf(selected).coerceAtLeast(0)); layout.addView(s)
        }
        label("Todorbit widget")
        label("Theme"); val theme=spinner(arrayOf("system","light","dark"),prefs.getString("theme-$id","system")!!)
        val filter=if(!calendar) {label("Task filter"); spinner(arrayOf("today","inbox","all"),prefs.getString("filter-$id","today")!!)} else null
        label("Opacity"); val opacity=SeekBar(this).apply {max=60; progress=prefs.getInt("opacity-$id",95)-40}; layout.addView(opacity)
        label("App lock hides widget details. Open Todorbit after changing tasks to refresh the projection.")
        layout.addView(Button(this).apply {text="Apply"; setOnClickListener {
            val edit=prefs.edit().putString("theme-$id",theme.selectedItem.toString()).putInt("opacity-$id",opacity.progress+40)
            filter?.let {edit.putString("filter-$id",it.selectedItem.toString())}; edit.apply()
            AndroidSurfaces.updateWidgets(this@WidgetConfigurationActivity)
            setResult(RESULT_OK,Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,id)); finish()
        }})
        setContentView(ScrollView(this).apply {
            addView(layout)
            ViewCompat.setOnApplyWindowInsetsListener(this) { view,insets ->
                val system=insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
                view.setPadding(system.left,system.top,system.right,system.bottom)
                insets
            }
        })
    }
}
