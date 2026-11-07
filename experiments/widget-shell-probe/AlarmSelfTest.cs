using Microsoft.Data.Sqlite;
using System.Text.Json;

internal static class AlarmSelfTest {
    internal static void Verify() {
        var root=Path.Combine(Path.GetTempPath(),"todorbit-alarms-"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        if(new WidgetSettings().LaunchAtSignIn)throw new InvalidOperationException("Fresh settings opted into startup");
        try {
            var file=Path.Combine(root,"synthetic.sqlite");
            using var db=new SqliteConnection($"Data Source={file};Pooling=False");db.Open();
            using var sql=db.CreateCommand();
            sql.CommandText="""
              PRAGMA user_version=28;
              CREATE TABLE tasks(id TEXT,title TEXT,status TEXT,scheduled_date TEXT,deleted_at TEXT,archived_at TEXT,category_id TEXT,project_id TEXT,notification_json TEXT);
              CREATE TABLE categories(id TEXT,deleted_at TEXT);
              CREATE TABLE projects(id TEXT,deleted_at TEXT);
              CREATE TABLE task_parent_links(child_id TEXT,parent_id TEXT);
              CREATE TABLE recurrence_occurrences(task_id TEXT,series_id TEXT);
              CREATE TABLE recurrence_series(id TEXT,family_id TEXT,deleted_at TEXT,archived_at TEXT);
              CREATE TABLE work_sessions(id TEXT,task_id TEXT,starts_at TEXT,ends_at TEXT,outcome TEXT,deleted_at TEXT,archived_at TEXT);
              CREATE TABLE fixed_events(id TEXT,title TEXT,starts_at TEXT,ends_at TEXT,recurrence_kind TEXT,recurrence_interval INTEGER DEFAULT 1,
                recurrence_weekdays TEXT,recurrence_until TEXT,active_from_date TEXT,active_through_date TEXT,all_day INTEGER DEFAULT 0,
                category_id TEXT,deleted_at TEXT,series_family_id TEXT);
              CREATE TABLE event_occurrence_changes(event_id TEXT,nominal_date TEXT,cancelled INTEGER,payload_json TEXT);
              CREATE TABLE task_reminder_deliveries(task_id TEXT,trigger_at TEXT,delivered_at TEXT,PRIMARY KEY(task_id,trigger_at));
              CREATE TABLE alarm_rules(id TEXT,task_id TEXT,event_id TEXT,series_id TEXT,nominal_date TEXT,config_json TEXT,deleted_at TEXT,archived_at TEXT);
              INSERT INTO tasks(id,title,status) VALUES('canary','Native alarm canary','notStarted');
              """;sql.ExecuteNonQuery();
            var now=DateTime.UtcNow;
            void Rule(DateTime at) {
                sql.CommandText="DELETE FROM alarm_rules; INSERT INTO alarm_rules(id,task_id,nominal_date,config_json) VALUES('rule','canary','',$json)";
                sql.Parameters.Clear();sql.Parameters.AddWithValue("$json",JsonSerializer.Serialize(new{version=1,mode="custom",at=at.ToString("O"),localMinute=540,minutesBefore=0,sound="alarm",vibrate=true,durationSeconds=15}));sql.ExecuteNonQuery();
            }
            using var repository=LifeManagerWidgetRepository.OpenForTest(file);
            sql.CommandText="UPDATE tasks SET notification_json=$json";
            sql.Parameters.AddWithValue("$json",JsonSerializer.Serialize(new{version=1,mode="custom",at=now.AddSeconds(-1).ToString("O")}));sql.ExecuteNonQuery();
            Rule(now.AddMinutes(1));
            var first=repository.LoadAlarms(now).Single();
            if(repository.ClaimTaskReminders(now.ToLocalTime()).Count!=0)throw new InvalidOperationException("Legacy reminder duplicated the explicit alarm");
            Rule(now.AddMinutes(2));
            if(repository.LoadAlarms(now).Single().Key==first.Key)throw new InvalidOperationException("Native alarm reschedule retained obsolete key");
            sql.CommandText="UPDATE tasks SET status='completed'";sql.Parameters.Clear();sql.ExecuteNonQuery();
            if(repository.LoadAlarms(now).Count!=0)throw new InvalidOperationException("Completed task alarm planned");
            sql.CommandText="UPDATE tasks SET status='notStarted',deleted_at='2026-01-01'";sql.ExecuteNonQuery();
            if(repository.LoadAlarms(now).Count!=0)throw new InvalidOperationException("Deleted task alarm planned");
            sql.CommandText="UPDATE tasks SET deleted_at=NULL";sql.ExecuteNonQuery();
            Rule(now.AddSeconds(-1));
            if(NativeAlarmRuntime.AllowedByWindows()) {
                using(var runtime=new NativeAlarmRuntime(repository,new PrivacyState(root),()=>WidgetPalette.Light,null)) {
                    runtime.Tick(DateTime.UtcNow);Application.DoEvents();
                    var window=Application.OpenForms.OfType<AlarmWindow>().Single();
                    Capture(window,"alarm-light.png");
                    var snooze=Descendants(window).OfType<Button>().Single(b=>b.Text=="Snooze 5 min");
                    snooze.PerformClick();Application.DoEvents();
                }
                var receiptFile=Path.Combine(root,"alarm-delivery-state.json");
                var receipts=JsonSerializer.Deserialize<Dictionary<string,AlarmReceipt>>(File.ReadAllText(receiptFile))!;
                if(receipts.Values.Single().State!="snoozed")throw new InvalidOperationException("Native snooze was not persisted");
                using(var resumed=new NativeAlarmRuntime(repository,new PrivacyState(root),()=>WidgetPalette.Dark,null)) {
                    resumed.Tick(DateTime.UtcNow);Application.DoEvents();
                    if(Application.OpenForms.OfType<AlarmWindow>().Any())throw new InvalidOperationException("Snooze fired before its due time");
                    resumed.Tick(DateTime.UtcNow.AddMinutes(5).AddSeconds(1));Application.DoEvents();
                    Capture(Application.OpenForms.OfType<AlarmWindow>().Single(),"alarm-dark.png");
                    Application.OpenForms.OfType<AlarmWindow>().Single().Close();Application.DoEvents();
                    resumed.Tick(DateTime.UtcNow.AddMinutes(5).AddSeconds(2));
                    if(Application.OpenForms.OfType<AlarmWindow>().Any())throw new InvalidOperationException("Dismissed alarm fired twice");
                }
                // Fail closed before showing/sounding if an atomic receipt write fails.
                File.Delete(receiptFile);Directory.CreateDirectory(receiptFile+".tmp");
                using var failed=new NativeAlarmRuntime(repository,new PrivacyState(root),()=>WidgetPalette.Light,null);
                var rejected=false;try{failed.Tick(DateTime.UtcNow);}catch(UnauthorizedAccessException){rejected=true;}catch(IOException){rejected=true;}
                if(!rejected || Application.OpenForms.OfType<AlarmWindow>().Any())throw new InvalidOperationException("Failed receipt write rang an alarm");
                Console.WriteLine("Native alarm: real scheduled window/audio API, snooze, restart, dismiss, duplicate and failed-write checks passed. Physical audibility unverified.");
            } else Console.WriteLine("Native alarm presentation BLOCKED by Windows notification state; planner checks passed.");
            sql.Parameters.Clear();
            sql.CommandText="INSERT INTO fixed_events(id,title,starts_at,ends_at,recurrence_kind,series_family_id) VALUES('event','Native quiz',$start,$end,'daily','event')";
            var start=new DateTime(now.AddHours(2).Ticks/TimeSpan.TicksPerSecond*TimeSpan.TicksPerSecond,DateTimeKind.Utc);
            sql.Parameters.AddWithValue("$start",start.ToString("O"));sql.Parameters.AddWithValue("$end",start.AddHours(1).ToString("O"));sql.ExecuteNonQuery();
            sql.Parameters.Clear();sql.CommandText="INSERT INTO alarm_rules(id,event_id,nominal_date,config_json) VALUES('event-rule','event','',$json)";
            sql.Parameters.AddWithValue("$json",JsonSerializer.Serialize(new{version=1,mode="relative",at=(string?)null,localMinute=540,minutesBefore=30,sound="alarm",vibrate=true,durationSeconds=15}));sql.ExecuteNonQuery();
            var eventPlan=repository.LoadAlarms(now).Where(a=>a.Kind=="event").ToArray();
            if(eventPlan.Length<2 || eventPlan[0].Due!=start.AddMinutes(-30))throw new InvalidOperationException("Native recurring event alarm timing failed");
            var nominal=start.ToLocalTime().ToString("yyyy-MM-dd");
            sql.Parameters.Clear();sql.CommandText="INSERT INTO event_occurrence_changes(event_id,nominal_date,cancelled) VALUES('event',$day,1)";
            sql.Parameters.AddWithValue("$day",nominal);sql.ExecuteNonQuery();
            if(repository.LoadAlarms(now).Any(a=>a.Kind=="event" && a.Nominal==nominal))throw new InvalidOperationException("Cancelled native event occurrence rang");
            Console.WriteLine("Native alarm event recurrence/offset/cancellation projection passed.");
            if(NativeAlarmRuntime.AllowedByWindows()) {
                var staging=Path.Combine(root,"alarm-delivery-state.json.tmp");if(Directory.Exists(staging))Directory.Delete(staging);
                sql.Parameters.Clear();sql.CommandText="UPDATE tasks SET status='completed'; DELETE FROM event_occurrence_changes; UPDATE fixed_events SET recurrence_kind=NULL,starts_at=$start,ends_at=$end; UPDATE alarm_rules SET config_json=json_set(config_json,'$.minutesBefore',0) WHERE event_id='event'";
                sql.Parameters.AddWithValue("$start",DateTime.UtcNow.AddSeconds(-1).ToString("O"));sql.Parameters.AddWithValue("$end",DateTime.UtcNow.AddHours(1).ToString("O"));sql.ExecuteNonQuery();
                using(var runtime=new NativeAlarmRuntime(repository,new PrivacyState(root),()=>WidgetPalette.Light,null)) {
                    runtime.Tick(DateTime.UtcNow);Application.DoEvents();
                    var window=Application.OpenForms.OfType<AlarmWindow>().Single();Capture(window,"alarm-event.png");window.Close();Application.DoEvents();
                    runtime.Tick(DateTime.UtcNow);
                    if(Application.OpenForms.OfType<AlarmWindow>().Any())throw new InvalidOperationException("Event alarm repeated after dismissal");
                }
                File.WriteAllText(Path.Combine(root,"privacy-settings.json"),"{\"enabled\":true,\"hideNotifications\":false}");
                sql.Parameters.Clear();sql.CommandText="UPDATE fixed_events SET title='Generic privacy canary',starts_at=$start";
                sql.Parameters.AddWithValue("$start",DateTime.UtcNow.AddSeconds(-3).ToString("O"));sql.ExecuteNonQuery();
                using(var generic=new NativeAlarmRuntime(repository,new PrivacyState(root),()=>WidgetPalette.Dark,null)) {
                    generic.Tick(DateTime.UtcNow);Application.DoEvents();
                    var window=Application.OpenForms.OfType<AlarmWindow>().Single();
                    if(Descendants(window).OfType<Label>().Any(l=>l.Text.Contains("privacy canary")))throw new InvalidOperationException("Locked alarm exposed its item title");
                    Capture(window,"alarm-generic.png");window.Close();Application.DoEvents();
                }
                Console.WriteLine("Native event background delivery/dismiss and locked generic presentation passed.");
            }
        } finally {SqliteConnection.ClearAllPools();Directory.Delete(root,true);}
    }
    private static void Capture(Form form,string name) {
        var directory=Environment.GetEnvironmentVariable("TODORBIT_ALARM_CAPTURE_DIR");if(string.IsNullOrWhiteSpace(directory))return;
        Directory.CreateDirectory(directory);using var image=new Bitmap(form.Width,form.Height);form.DrawToBitmap(image,new Rectangle(Point.Empty,form.Size));image.Save(Path.Combine(directory,name),System.Drawing.Imaging.ImageFormat.Png);
    }
    private static IEnumerable<Control> Descendants(Control control) {
        foreach(Control child in control.Controls){yield return child;foreach(var nested in Descendants(child))yield return nested;}
    }
}
