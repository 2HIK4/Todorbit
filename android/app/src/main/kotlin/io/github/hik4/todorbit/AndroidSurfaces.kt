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
import java.util.UUID
import java.time.Instant
import android.text.format.DateFormat
import android.util.SizeF
import android.os.Build
import java.util.concurrent.Executors
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/** Read-only projections from the shared Dart repository; never opens SQLite. */
object AndroidSurfaces {
    private val worker = Executors.newSingleThreadExecutor()
    fun enqueue(action: () -> Unit) { worker.execute(action) }
    const val channelId = "todorbit_reminders"
    // Process-local: a crashed/killed app never leaves a persisted unlock grant.
    @Volatile var foregroundUnlocked = false
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
    // Commands are capabilities issued only by our private widget projection. A
    // public deep link cannot manufacture a completion operation or choose an ID.
    fun claimWidgetAction(context: Context, raw: String): Map<String, Any>? {
        if (privacy(context).optBoolean("enabled",true) && !foregroundUnlocked) return null
        val uri = Uri.parse(raw)
        if(uri.scheme != "todorbit" || uri.host != "widget-action") return null
        val id = uri.getQueryParameter("widget")?.toIntOrNull() ?: return null
        val token = uri.getQueryParameter("token") ?: return null
        val prefs = preferences(context)
        val actions = JSONObject(prefs.getString("actions-$id", "{}")!!)
        val command = actions.optJSONObject(token) ?: return null
        actions.remove(token)
        check(prefs.edit().putString("actions-$id", actions.toString()).commit())
        return mapOf("id" to command.getString("id"), "revision" to command.getString("revision"), "complete" to command.getBoolean("complete"))
    }

    fun render(context: Context, manager: AppWidgetManager, id: Int, calendar: Boolean) {
        val options = manager.getAppWidgetOptions(id)
        // Exact responsive variants on Android 12+, both orientations on API 26-30.
        if (Build.VERSION.SDK_INT >= 31) {
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            if (!sizes.isNullOrEmpty()) {
                val actions = widgetActions(context,id,calendar)
                manager.updateAppWidget(id, RemoteViews(sizes.distinct().take(16).associateWith {
                    widgetView(context,id,calendar,it.width.toInt(),it.height.toInt(),actions)
                }))
                return
            }
        }
        val actions = widgetActions(context,id,calendar)
        manager.updateAppWidget(id, RemoteViews(
            widgetView(context,id,calendar,options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH,300),options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,180),actions),
            widgetView(context,id,calendar,options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,180),options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,300),actions)))
    }

    private fun widgetActions(context: Context, id: Int, calendar: Boolean): JSONObject {
        val prefs = preferences(context)
        val old = JSONObject(prefs.getString("actions-$id", "{}")!!)
        val previous = old.keys().asSequence().associateBy { old.getJSONObject(it).toString() }
        val next = JSONObject()
        // Keep commands stable across redraw/resize, but expire obsolete revisions.
        if(!calendar) {
            val tasks = snapshot(context).optJSONArray("tasks") ?: JSONArray()
            for(i in 0 until tasks.length()) {
                val t = tasks.getJSONObject(i)
                if(!t.has("revision")) continue // Old APK projection: open app to refresh.
                val command = JSONObject().put("id",t.getString("id"))
                    .put("revision",t.getString("revision")).put("complete",!t.optBoolean("done"))
                val token = previous[command.toString()] ?: UUID.randomUUID().toString()
                next.put(token,command)
            }
        }
        prefs.edit().putString("actions-$id",next.toString()).apply()
        return next
    }

    private fun rowDetail(context: Context, item: JSONObject, calendar: Boolean, today: LocalDate): String {
        return if(calendar) {
                val start=Instant.ofEpochMilli(item.getLong("at")).atZone(ZoneId.systemDefault())
                val end=Instant.ofEpochMilli(item.getLong("until")).atZone(ZoneId.systemDefault())
                val date=if(start.toLocalDate()==today) "Today" else start.format(DateTimeFormatter.ofPattern("EEE, MMM d"))
                val time=if(item.optBoolean("allDay")) "All day" else DateFormat.getTimeFormat(context).format(java.util.Date(item.getLong("at")))+" \u2013 "+DateFormat.getTimeFormat(context).format(java.util.Date(item.getLong("until")))
                date+" \u00b7 "+time+if(item.optString("kind")=="session") " \u00b7 Session" else if(end.toLocalDate()>start.toLocalDate()) " \u00b7 "+end.format(DateTimeFormatter.ofPattern("MMM d")) else ""
            } else if(item.optBoolean("done")) "Completed" else if(item.optString("due").isNotEmpty()) {
                val due=try {LocalDate.parse(item.getString("due")).format(DateTimeFormatter.ofPattern("MMM d"))} catch (_: Exception) {item.getString("due")}
                "Due $due"
            } else item.optString("detail")
    }

    private fun widgetView(context: Context, id: Int, calendar: Boolean, width: Int, height: Int, actions: JSONObject): RemoteViews {
        val prefs = preferences(context)
        val data = snapshot(context)
        val theme = prefs.getString("theme-$id","system")
        val dark = theme == "dark" || theme == "system" && (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val palette = data.optJSONObject("palettes")?.optJSONObject(if(dark) "dark" else "light")
        fun color(key: String, fallback: String) = try { Color.parseColor(palette?.optString(key,fallback) ?: fallback) } catch (_: Exception) { Color.parseColor(fallback) }
        val surface = color("surface",if(dark) "#252131" else "#FFFFFF")
        fun contrastText(candidate: Int): Int {
            fun light(c: Int): Double {
                fun channel(v: Int): Double { val n=v/255.0; return if(n<=0.04045) n/12.92 else Math.pow((n+0.055)/1.055,2.4) }
                return .2126*channel(Color.red(c))+.7152*channel(Color.green(c))+.0722*channel(Color.blue(c))
            }
            val a=light(surface); val b=light(candidate)
            return if((maxOf(a,b)+.05)/(minOf(a,b)+.05)>=4.5) candidate else if(a>.179) Color.BLACK else Color.WHITE
        }
        val foreground = contrastText(color("primaryText",if(dark) "#F4F0FC" else "#211B35"))
        val secondary = contrastText(color("secondaryText",if(dark) "#C8C0D5" else "#665F78"))
        val accent = contrastText(color("accent",if(dark) "#B9A4F4" else "#6D56BD"))
        val opacity = prefs.getInt("opacity-$id",95).coerceIn(40,100)
        val remote = RemoteViews(context.packageName,R.layout.todorbit_widget)
        // Opacity belongs to the outer shell; opaque content surfaces keep text
        // readable on arbitrary launcher wallpapers, including custom colors.
        remote.setInt(R.id.widget_shell,"setColorFilter",surface)
        remote.setInt(R.id.widget_shell,"setImageAlpha",opacity*255/100)
        remote.setInt(R.id.widget_surface,"setColorFilter",surface)
        val today = LocalDate.now()
        val day = today.toString()
        val filter = prefs.getString("filter-$id","today")
        fun link(kind: String) = "todorbit://$kind?day=$day&widget=$id"
        val destination = if(calendar) link("calendar") else link("tasks")+"&filter=$filter"
        remote.setTextViewText(R.id.widget_title,if(calendar) "Calendar" else when(filter) { "all" -> "Tasks"; "inbox" -> "Inbox"; else -> "Today" })
        remote.setTextColor(R.id.widget_title,foreground)
        remote.setOnClickPendingIntent(R.id.widget_heading,open(context,destination))
        remote.setOnClickPendingIntent(R.id.widget_add,open(context,link(if(calendar) "add-event" else "add")))
        remote.setContentDescription(R.id.widget_add,if(calendar) "Add event" else "Add task")
        remote.setTextColor(R.id.widget_add,accent)
        remote.removeAllViews(R.id.widget_rows)
        remote.removeAllViews(R.id.widget_week)
        val hidden = privacy(context).optBoolean("enabled",true) || data.optBoolean("private",true)
        val source = data.optJSONArray(if(calendar) "agenda" else "tasks") ?: JSONArray()
        val midnight = today.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val items = if(hidden) emptyList() else (0 until source.length()).map { source.getJSONObject(it) }.filter {
            if(calendar) it.optLong("until",0L)>midnight
            else when(filter) { "inbox" -> it.optBoolean("inbox"); "all" -> true; else -> it.optString("day")==day }
        }
        val expanded = calendar && height >= 330 && context.resources.configuration.fontScale <= 1.3f
        remote.setViewVisibility(R.id.widget_week,if(expanded) View.VISIBLE else View.GONE)
        if(expanded) {
            val days = if(width >= 360) 7 else 3
            for(n in 0 until days) {
                val date=today.plusDays(n.toLong())
                val cell=RemoteViews(context.packageName,R.layout.todorbit_widget_day)
                val count=items.count { it.optString("kind")=="event" && it.optString("day")<=date.toString() && it.optString("through")>=date.toString() }
                cell.setTextViewText(R.id.widget_day,date.format(DateTimeFormatter.ofPattern("EEE"))+"\n"+date.dayOfMonth+if(count>0) " \u00b7 $count" else "")
                cell.setTextColor(R.id.widget_day,if(n==0) accent else secondary)
                cell.setContentDescription(R.id.widget_day,"${date.format(DateTimeFormatter.ofLocalizedDate(java.time.format.FormatStyle.FULL))}, $count events")
                cell.setOnClickPendingIntent(R.id.widget_day,open(context,"todorbit://calendar?day=$date&widget=$id"))
                remote.addView(R.id.widget_week,cell)
            }
        }
        val scale=context.resources.configuration.fontScale
        val compact = height < 250
        remote.setViewVisibility(R.id.widget_context,if(compact && scale>1.3f) View.GONE else View.VISIBLE)
        remote.setInt(R.id.widget_empty,"setMaxLines",if(compact) 1 else 3)
        if(compact) {
            val padding=(4*context.resources.displayMetrics.density).toInt()
            remote.setViewPadding(R.id.widget_empty,0,padding,0,padding)
        }
        // Measure bounded text layouts rather than reserving two lines for
        // every row. Extra height can then show actual content at each font size.
        val density=context.resources.displayMetrics.density
        fun dp(value: Int)=(value*density).toInt()
        fun textHeight(text: String, sp: Float, lines: Int, bold: Boolean, widthDp: Int): Int {
            val paint=android.text.TextPaint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                textSize=android.util.TypedValue.applyDimension(android.util.TypedValue.COMPLEX_UNIT_SP,sp,context.resources.displayMetrics)
                typeface=if(bold) android.graphics.Typeface.DEFAULT_BOLD else android.graphics.Typeface.DEFAULT
            }
            return android.text.StaticLayout.Builder.obtain(text,0,text.length,paint,dp(widthDp).coerceAtLeast(1))
                .setIncludePad(true).setMaxLines(lines).setEllipsize(android.text.TextUtils.TruncateAt.END).build().height
        }
        val headerWidth=(width-72).coerceAtLeast(1)
        val headerHeight=dp(24)+maxOf(dp(48),textHeight("Ag",18f,1,true,headerWidth)+
            if(compact && scale>1.3f) 0 else textHeight("Ag",12f,1,false,headerWidth))
        val footerHeight=maxOf(dp(48),textHeight("${items.size} more \u00b7 Open ${if(calendar) "calendar" else "tasks"}",12f,2,false,width-24))
        var used=headerHeight+footerHeight+if(expanded) dp(64) else 0
        var capacity=0
        val bodyWidth=width-24-if(calendar) 15 else 48
        for(item in items.take(16)) {
            val rowHeight=maxOf(dp(60),dp(16)+textHeight(item.getString("title"),15f,if(compact) 1 else 2,true,bodyWidth)+
                textHeight(rowDetail(context,item,calendar,today),12f,if(compact) 1 else 2,false,bodyWidth))
            if(used+rowHeight>dp(height)) break
            used+=rowHeight
            capacity++
        }
        remote.setTextViewText(R.id.widget_context, today.format(DateTimeFormatter.ofPattern("EEE, MMM d")) + if(hidden) "" else if(calendar) " \u00b7 ${items.size} ${if(items.size==1) "item" else "items"}" else " \u00b7 ${items.count {!it.optBoolean("done")}} remaining")
        remote.setTextColor(R.id.widget_context,secondary)
        for(item in items.take(capacity)) {
            val row=RemoteViews(context.packageName,R.layout.todorbit_widget_row)
            row.setTextViewText(R.id.widget_row_title,item.getString("title"))
            row.setInt(R.id.widget_row_title,"setMaxLines",if(!compact) 2 else 1)
            row.setInt(R.id.widget_row_detail,"setMaxLines",if(compact) 1 else 2)
            val detail = rowDetail(context,item,calendar,today)
            row.setTextViewText(R.id.widget_row_detail,detail)
            row.setTextColor(R.id.widget_row_title,foreground)
            row.setTextColor(R.id.widget_row_detail,secondary)
            row.setInt(R.id.widget_row_accent,"setBackgroundColor",if(item.has("color")) item.getLong("color").toInt() else accent)
            row.setViewVisibility(R.id.widget_row_accent,if(calendar) View.VISIBLE else View.GONE)
            row.setViewVisibility(R.id.widget_complete,if(calendar) View.GONE else View.VISIBLE)
            // Text and completion are siblings: a parent click cannot steal the checkbox.
            row.setOnClickPendingIntent(R.id.widget_row_body,open(context,item.getString("link")+"&widget=$id"))
            if(!calendar) {
                val token=actions.keys().asSequence().firstOrNull { actions.getJSONObject(it).optString("id")==item.optString("id") }
                row.setTextViewText(R.id.widget_complete,if(item.optBoolean("done")) "\u2611" else "\u2610")
                row.setTextColor(R.id.widget_complete,accent)
                row.setContentDescription(R.id.widget_complete,(if(item.optBoolean("done")) "Reopen " else "Complete ")+item.getString("title")+". Opens Todorbit; unlock if required.")
                row.setOnClickPendingIntent(R.id.widget_complete,open(context,if(token==null) item.getString("link") else "todorbit://widget-action?widget=$id&token=$token"))
            }
            remote.addView(R.id.widget_rows,row)
        }
        remote.setViewVisibility(R.id.widget_empty,if(items.isEmpty() || capacity==0) View.VISIBLE else View.GONE)
        remote.setTextColor(R.id.widget_empty,secondary)
        remote.setTextViewText(R.id.widget_empty,if(hidden) if(compact) "Locked" else "Details hidden by app lock. Open Todorbit to unlock." else if(capacity==0 && items.isNotEmpty()) "Resize" else if(calendar) if(compact) "No events" else "No upcoming events. Make room for what matters." else if(compact) "All clear." else "All clear here. Add a task when you are ready.")
        remote.setTextColor(R.id.widget_footer,accent)
        remote.setTextViewText(R.id.widget_footer,if(hidden) "Open Todorbit" else if(items.isEmpty()) if(calendar) "Add event  +" else "Add task  +" else if(items.size>capacity) "${items.size-capacity} more \u00b7 Open ${if(calendar) "calendar" else "tasks"}" else "Open ${if(calendar) "calendar" else "tasks"}  \u203a")
        remote.setOnClickPendingIntent(R.id.widget_footer,open(context,if(!hidden && items.isEmpty()) link(if(calendar) "add-event" else "add") else destination))
        return remote
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
        val pending=goAsync()
        AndroidSurfaces.enqueue {
            try {
                AndroidSurfaces.scheduleReminders(context)
                AndroidSurfaces.updateWidgets(context)
                AndroidSurfaces.scheduleRefresh(context)
                ReminderRefreshJob.schedule(context)
                ReminderRefreshJob.schedule(context,true)
            } catch (error: Exception) { android.util.Log.w("TodorbitWidgets","Widget refresh failed",error) } finally { pending.finish() }
        }
    }
}

class TasksWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending=goAsync()
        AndroidSurfaces.enqueue { try { for(id in ids) AndroidSurfaces.render(context,manager,id,false) } catch (error: Exception) { android.util.Log.w("TodorbitWidgets","Widget refresh failed",error) } finally { pending.finish() } }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        val pending=goAsync()
        AndroidSurfaces.enqueue { try { AndroidSurfaces.render(context,manager,id,false) } catch (error: Exception) { android.util.Log.w("TodorbitWidgets","Widget refresh failed",error) } finally { pending.finish() } }
    }
    override fun onDeleted(context: Context, ids: IntArray) { for(id in ids) AndroidSurfaces.preferences(context).edit().remove("theme-$id").remove("filter-$id").remove("opacity-$id").remove("actions-$id").apply() }
}
class CalendarWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending=goAsync()
        AndroidSurfaces.enqueue { try { for(id in ids) AndroidSurfaces.render(context,manager,id,true) } catch (error: Exception) { android.util.Log.w("TodorbitWidgets","Widget refresh failed",error) } finally { pending.finish() } }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        val pending=goAsync()
        AndroidSurfaces.enqueue { try { AndroidSurfaces.render(context,manager,id,true) } catch (error: Exception) { android.util.Log.w("TodorbitWidgets","Widget refresh failed",error) } finally { pending.finish() } }
    }
    override fun onDeleted(context: Context, ids: IntArray) { for(id in ids) AndroidSurfaces.preferences(context).edit().remove("theme-$id").remove("filter-$id").remove("opacity-$id").remove("actions-$id").apply() }
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
            AndroidSurfaces.enqueue { AndroidSurfaces.updateWidgets(this@WidgetConfigurationActivity) }
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
