package io.github.hik4.todorbit

import android.app.Instrumentation
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.FrameLayout
import android.widget.RemoteViews
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.LocalDate
import java.time.ZoneId

/** Opt-in native rendering acceptance. Never opens or changes SQLite. */
class WidgetRenderInstrumentation : Instrumentation() {
    private var isolated = false
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        isolated = arguments?.getString("isolated") == "true"
        start()
    }

    override fun onStart() {
        val result = Bundle()
        var activity: WidgetConfigurationActivity? = null
        val prefs = AndroidSurfaces.preferences(targetContext)
        val original = prefs.getString("snapshot", null)
        val ids = listOf(23001, 23002)
        var changed = false
        try {
            check(isolated && Build.HARDWARE in listOf("ranchu", "goldfish")) {
                "Requires -e isolated true on an explicitly disposable Android emulator"
            }
            check(!AndroidSurfaces.privacy(targetContext).optBoolean("enabled", true)) {
                "Use a disposable unlocked profile; never disable a personal lock for testing"
            }
            check(ids.none { id ->
                AppWidgetManager.getInstance(targetContext).getAppWidgetInfo(id) != null ||
                    listOf("theme-$id", "filter-$id", "opacity-$id", "actions-$id").any { prefs.contains(it) }
            }) { "Native render fixture IDs are already in use; choose a fresh disposable profile" }
            // Configuration activity is only a temporary window for real RemoteViews.
            activity = startActivitySync(Intent(targetContext, WidgetConfigurationActivity::class.java)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, 23001)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as WidgetConfigurationActivity
            val output = File(targetContext.cacheDir, "widget-render-acceptance").apply { mkdirs() }
            val actionsMethod = AndroidSurfaces::class.java.getDeclaredMethod("widgetActions",
                android.content.Context::class.java, Int::class.javaPrimitiveType, Boolean::class.javaPrimitiveType).apply { isAccessible = true }
            val viewMethod = AndroidSurfaces::class.java.getDeclaredMethod("widgetView",
                android.content.Context::class.java, Int::class.javaPrimitiveType, Boolean::class.javaPrimitiveType,
                Int::class.javaPrimitiveType, Int::class.javaPrimitiveType, JSONObject::class.java).apply { isAccessible = true }
            var captures = 0
            val bounds = JSONArray()
            for (densityDpi in listOf(420, 560)) for (scale in listOf(1f, 2f)) for (dark in listOf(false, true)) for (calendar in listOf(false, true)) {
                val configuration = android.content.res.Configuration(targetContext.resources.configuration).apply {
                    fontScale = scale
                    this.densityDpi = densityDpi
                }
                val renderContext = targetContext.createConfigurationContext(configuration)
                for (count in listOf(0, 1, 12)) for ((width, height) in listOf(180 to 180, 280 to 280, 380 to 540, 280 to 180)) {
                    val id = if (dark) ids[1] else ids[0]
                    val source = fixture(count)
                    changed = true
                    check(prefs.edit().putString("snapshot", source.toString())
                        .putString("theme-$id", if (dark) "dark" else "light")
                        .putString("filter-$id", "all").putInt("opacity-$id", 40).commit())
                    val actions = actionsMethod.invoke(AndroidSurfaces, targetContext, id, calendar) as JSONObject
                    val remote = viewMethod.invoke(AndroidSurfaces, renderContext, id, calendar, width, height, actions) as RemoteViews
                    runOnMainSync {
                        val window = FrameLayout(activity).apply {
                            setBackgroundColor(0xFF808080.toInt())
                            // This edge-to-edge test window has a native action bar.
                            // Keep the entire widget below it in screenshot evidence.
                            setPadding(0, (96 * targetContext.resources.displayMetrics.density).toInt(), 0, 0)
                        }
                        val view = remote.apply(renderContext, window)
                        val density = renderContext.resources.displayMetrics.density
                        window.addView(view, FrameLayout.LayoutParams((width * density).toInt(), (height * density).toInt()))
                        activity.setContentView(window)
                    }
                    waitForIdleSync()
                    SystemClock.sleep(150)
                    runOnMainSync {
                        val root = activity.findViewById<View>(R.id.widget_root)
                        val footer = activity.findViewById<TextView>(R.id.widget_footer)
                        val content = activity.findViewById<View>(R.id.widget_content)
                        check(root.width > 0 && footer.bottom <= content.height - content.paddingBottom) {
                            "Clipped footer at $width x $height, count=$count, calendar=$calendar, font=$scale"
                        }
                        val rootLocation = IntArray(2).also { root.getLocationOnScreen(it) }
                        val footerLocation = IntArray(2).also { footer.getLocationOnScreen(it) }
                        val left = footerLocation[0] - rootLocation[0]
                        val top = footerLocation[1] - rootLocation[1]
                        check(left >= content.paddingLeft && left + footer.width <= root.width - content.paddingRight)
                        check(top >= 0 && top + footer.height <= root.height - content.paddingBottom)
                        check(footer.height >= 48 * renderContext.resources.displayMetrics.density - 1 && footer.hasOnClickListeners())
                        check(footer.importantForAccessibility != View.IMPORTANT_FOR_ACCESSIBILITY_NO && footer.text.isNotBlank())
                        val layout = footer.layout ?: error("Footer text is not laid out")
                        val textWidth = footer.width - footer.compoundPaddingLeft - footer.compoundPaddingRight
                        for (line in 0 until layout.lineCount) {
                            check(layout.getLineLeft(line) >= -1f && layout.getLineRight(line) <= textWidth + 1f && layout.getEllipsisCount(line) == 0) {
                                "Clipped footer glyphs: ${footer.text}, line=$line, $width x $height, font=$scale, density=$densityDpi"
                            }
                        }
                        val visible = Rect()
                        footer.getGlobalVisibleRect(visible)
                        bounds.put(JSONObject().put("kind", if(calendar) "calendar" else "tasks").put("width", width).put("height", height)
                            .put("count", count).put("font", scale).put("density", densityDpi).put("text", footer.text.toString())
                            .put("rootX",rootLocation[0]).put("rootY",rootLocation[1]).put("footerLeft",left).put("footerTop",top)
                            .put("footerWidth",footer.width).put("footerHeight",footer.height).put("globalVisible",visible.toShortString()))
                        // Widget-local render avoids mistaking a test-window/screen crop for product clipping.
                        val local = Bitmap.createBitmap(root.width, root.height, Bitmap.Config.ARGB_8888)
                        root.draw(Canvas(local))
                        val localName = "${if(calendar) "calendar" else "tasks"}-${if(dark) "dark" else "light"}-${width}x$height-$count-font${(scale*100).toInt()}-dpi$densityDpi-local.png"
                        File(output, localName).outputStream().use { local.compress(Bitmap.CompressFormat.PNG,100,it) }
                        local.recycle()
                    }
                    val name = "${if(calendar) "calendar" else "tasks"}-${if(dark) "dark" else "light"}-${width}x$height-$count-font${(scale*100).toInt()}-dpi$densityDpi.png"
                    val bitmap = uiAutomation.takeScreenshot() ?: error("Screenshot unavailable")
                    File(output, name).outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    bitmap.recycle()
                    captures++
                }
            }
            File(output,"footer-bounds.json").writeText(bounds.toString(2))
            // Exercise capability identity, bridge types, one-use consumption and
            // invalid-token rejection using two same-title IDs and two instances.
            prefs.edit().putString("snapshot", fixture(2).toString()).commit()
            val first = actionsMethod.invoke(AndroidSurfaces, targetContext, ids[0], false) as JSONObject
            val second = actionsMethod.invoke(AndroidSurfaces, targetContext, ids[1], false) as JSONObject
            val token = first.keys().next()
            check(!second.has(token))
            val command = AndroidSurfaces.claimWidgetAction(targetContext,
                "todorbit://widget-action?widget=${ids[0]}&token=$token") ?: error("Missing action")
            check(command["id"] == first.getJSONObject(token).getString("id") && command["complete"] == true)
            check(AndroidSurfaces.claimWidgetAction(targetContext,
                "todorbit://widget-action?widget=${ids[0]}&token=$token") == null)
            check(AndroidSurfaces.claimWidgetAction(targetContext,
                "todorbit://widget-action?widget=${ids[1]}&token=invalid") == null)
            result.putString("stream", "$captures real native screenshots; geometry and capability checks passed. $output\n")
        } catch (error: Throwable) {
            result.putString("stream", "Native widget acceptance failed: $error\n${error.stackTraceToString()}")
            result.putString("failure", error.toString())
        } finally {
            if (changed) {
                val edit = prefs.edit()
                if (original == null) edit.remove("snapshot") else edit.putString("snapshot", original)
                for (id in ids) edit.remove("theme-$id").remove("filter-$id").remove("opacity-$id").remove("actions-$id")
                check(edit.commit())
                AndroidSurfaces.updateWidgets(targetContext)
            }
            activity?.let { runOnMainSync { it.finish() } }
        }
        finish(if (result.containsKey("failure")) 1 else -1, result)
    }

    private fun fixture(count: Int): JSONObject {
        val day = LocalDate.now()
        val midnight = day.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val tasks = JSONArray()
        val agenda = JSONArray()
        for (n in 0 until count) {
            tasks.put(JSONObject().put("id", "native-fixture-$n")
                .put("title", if (n < 2) "Same title, distinct identity" else "Review the next milestone $n")
                .put("day", day.toString()).put("detail", "Not started").put("done", false)
                .put("revision", "2026-10-30T00:00:00.000Z").put("inbox", true)
                .put("link", "todorbit://task?id=native-fixture-$n"))
            val date = day.plusDays((n / 3).toLong()).toString()
            agenda.put(JSONObject().put("title", "Upcoming review ${n + 1}")
                .put("kind", if (n % 3 == 2) "session" else "event").put("allDay", n == 1)
                .put("day", date).put("through", date)
                .put("at", midnight + (n / 3) * 86400000L + (9 + n % 3) * 3600000L)
                .put("until", midnight + (n / 3) * 86400000L + (10 + n % 3) * 3600000L)
                .put("link", "todorbit://event?id=native-fixture-$n&day=$date"))
        }
        return JSONObject().put("version", 1).put("private", false)
            .put("tasks", tasks).put("agenda", agenda).put("reminders", JSONArray())
    }
}
