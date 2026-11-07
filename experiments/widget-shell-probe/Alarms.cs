using System.Globalization;
using System.Text.Json;
using System.Media;
using System.Runtime.InteropServices;
using System.Diagnostics;

internal sealed record NativeAlarm(string Key,string Title,DateTime Due,string Kind,
    string EntityId,string? Nominal,string Sound,int Duration,DateTime? StartsAt=null,bool Generic=false);
internal sealed record NativeAlarmRule(string Id,string? Task,string? Event,string? Series,
    string Nominal,JsonElement Config);

internal sealed partial class LifeManagerWidgetRepository {
    private bool HasItemAlarm(string kind,string id,string nominal,Microsoft.Data.Sqlite.SqliteTransaction transaction) {
        if(schemaVersion<28)return false;
        using var command=connection.CreateCommand();command.Transaction=transaction;
        command.CommandText=kind=="task"?"""
          SELECT config_json FROM alarm_rules WHERE deleted_at IS NULL AND archived_at IS NULL AND
          (task_id=$id OR series_id IN (SELECT s.id FROM recurrence_occurrences o JOIN recurrence_series s ON s.id=o.series_id WHERE o.task_id=$id
          UNION SELECT s.family_id FROM recurrence_occurrences o JOIN recurrence_series s ON s.id=o.series_id WHERE o.task_id=$id))
          ORDER BY (task_id=$id) DESC LIMIT 1
          """:"""
          SELECT config_json FROM alarm_rules WHERE deleted_at IS NULL AND archived_at IS NULL AND
          (event_id=$id OR event_id=(SELECT coalesce(series_family_id,id) FROM fixed_events WHERE id=$id))
          AND nominal_date IN ('',$nominal) ORDER BY (nominal_date!='') DESC,(event_id=$id) DESC LIMIT 1
          """;
        command.Parameters.AddWithValue("$id",id);
        if(kind!="task")command.Parameters.AddWithValue("$nominal",nominal);
        if(command.ExecuteScalar() is not string json)return false;
        using var value=JsonDocument.Parse(json);return value.RootElement.GetProperty("mode").GetString()!="off";
    }

    internal IReadOnlyList<NativeAlarm> LoadAlarms(DateTime utcNow) {
        RefreshSchemaVersion();
        if(schemaVersion<28) return [];
        var rules=new List<NativeAlarmRule>();
        using(var command=connection.CreateCommand()) {
            command.CommandText="SELECT id,task_id,event_id,series_id,nominal_date,config_json FROM alarm_rules WHERE deleted_at IS NULL AND archived_at IS NULL";
            using var r=command.ExecuteReader();
            while(r.Read()) {
                using var doc=JsonDocument.Parse(r.GetString(5));
                rules.Add(new(r.GetString(0),r.IsDBNull(1)?null:r.GetString(1),r.IsDBNull(2)?null:r.GetString(2),r.IsDBNull(3)?null:r.GetString(3),r.GetString(4),doc.RootElement.Clone()));
            }
        }
        if(rules.Count==0) return [];
        var result=new List<NativeAlarm>();
        void Add(NativeAlarmRule? rule,string kind,string id,string? nominal,string title,DateTime? planned,DateTime? start) {
            if(rule==null) return;
            var c=rule.Config;var mode=c.GetProperty("mode").GetString();
            if(mode=="off") return;
            DateTime? due=mode switch {
                "custom"=>DateTimeOffset.Parse(c.GetProperty("at").GetString()!,CultureInfo.InvariantCulture).UtcDateTime,
                "planned" when planned!=null=>planned.Value.Date.AddMinutes(c.GetProperty("localMinute").GetInt32()).ToUniversalTime(),
                "relative" when start!=null=>start.Value.ToUniversalTime(), _=>null
            };
            if(due==null) return;
            if(mode!="custom")due=due.Value.AddMinutes(-c.GetProperty("minutesBefore").GetInt32());
            if(due<utcNow.AddHours(-24) || due>utcNow.AddDays(93)) return;
            var key=$"alarm:{rule.Id}:{kind}:{id}:{nominal ?? ""}:{new DateTimeOffset(due.Value).ToUnixTimeMilliseconds()}";
            result.Add(new(key,title,due.Value,kind,id,nominal,c.GetProperty("sound").GetString()!,c.GetProperty("durationSeconds").GetInt32(),mode=="planned" && planned!=null?planned.Value.Date.AddMinutes(c.GetProperty("localMinute").GetInt32()).ToUniversalTime():start?.ToUniversalTime()));
        }
        using(var command=connection.CreateCommand()) {
            command.CommandText="""
              SELECT tasks.id,tasks.title,tasks.scheduled_date,s.id,s.family_id,
                (SELECT MIN(w.starts_at) FROM work_sessions w WHERE w.task_id=tasks.id
                  AND w.deleted_at IS NULL AND w.archived_at IS NULL AND w.outcome='upcoming'
                  AND julianday(w.ends_at)>julianday($now))
              FROM tasks LEFT JOIN recurrence_occurrences o ON o.task_id=tasks.id
              LEFT JOIN recurrence_series s ON s.id=o.series_id
              WHERE tasks.status NOT IN ('completed','cancelled')
              """+ActiveTaskClause.Replace("AND deleted_at", "AND tasks.deleted_at").Replace("AND archived_at", "AND tasks.archived_at")
                .Replace("(category_id", "(tasks.category_id").Replace("(project_id", "(tasks.project_id")+ActiveParentClause;
            command.Parameters.AddWithValue("$now",utcNow.ToString("O"));
            using var r=command.ExecuteReader();
            while(r.Read()) {
                var id=r.GetString(0);var series=r.IsDBNull(3)?null:r.GetString(3);var family=r.IsDBNull(4)?null:r.GetString(4);
                var rule=rules.FirstOrDefault(a=>a.Task==id) ?? rules.FirstOrDefault(a=>a.Series!=null && (a.Series==series || a.Series==family));
                Add(rule,"task",id,null,r.GetString(1),r.IsDBNull(2)?null:DateTime.ParseExact(r.GetString(2),"yyyy-MM-dd",CultureInfo.InvariantCulture),r.IsDBNull(5)?null:DateTimeOffset.Parse(r.GetString(5),CultureInfo.InvariantCulture).LocalDateTime);
            }
        }
        if(!rules.Any(r=>r.Event!=null)) return result.OrderBy(a=>a.Due).ToArray();
        var families=new Dictionary<string,string>();
        using(var command=connection.CreateCommand()) {
            command.CommandText="SELECT id,coalesce(series_family_id,id) FROM fixed_events";
            using var r=command.ExecuteReader();while(r.Read())families[r.GetString(0)]=r.GetString(1);
        }
        // Existing native recurrence/exception projection, not a second recurrence engine.
        foreach(var e in LoadCalendarItems(utcNow.ToLocalTime().Date.AddDays(-1),utcNow.ToLocalTime().Date.AddDays(9),forNotifications:true)
            .Where(e=>e.Kind=="Event" && !e.Cancelled).DistinctBy(e=>(e.Id,e.NominalDate,e.StartsAt))) {
            var owners=new[]{e.Id,families.GetValueOrDefault(e.Id,e.Id)};
            NativeAlarmRule? rule=null;
            if(e.NominalDate!=null)foreach(var owner in owners) {
                rule=rules.FirstOrDefault(a=>a.Event==owner && a.Nominal==e.NominalDate);if(rule!=null)break;
            }
            if(rule==null)foreach(var owner in owners) {
                rule=rules.FirstOrDefault(a=>a.Event==owner && a.Nominal=="");if(rule!=null)break;
            }
            Add(rule,"event",e.Id,e.NominalDate,e.Title,null,e.StartsAt);
        }
        return result.OrderBy(a=>a.Due).DistinctBy(a=>a.Key).ToArray();
    }
}

internal sealed record AlarmReceipt(DateTime Due,string State,DateTime Updated);

/// Single existing companion owns this device-local state; never enters Sync.
internal sealed class NativeAlarmRuntime : IDisposable {
    private readonly LifeManagerWidgetRepository repository;
    private readonly PrivacyState privacy;
    private readonly Func<WidgetPalette> palette;
    private readonly string? appExe;
    private readonly string statePath;
    private Dictionary<string,AlarmReceipt> state;
    private readonly Dictionary<string,AlarmWindow> windows=[];
    private IReadOnlyList<NativeAlarm> plans=[];
    private DateTime nextRead=DateTime.MinValue,lastTick=DateTime.MinValue;
    internal NativeAlarmRuntime(LifeManagerWidgetRepository repository,PrivacyState privacy,Func<WidgetPalette> palette,string? appExe) {
        this.repository=repository;this.privacy=privacy;this.palette=palette;this.appExe=appExe ?? (File.Exists(Path.Combine(AppContext.BaseDirectory,"Todorbit.exe"))?Path.Combine(AppContext.BaseDirectory,"Todorbit.exe"):null);
        statePath=Path.Combine(Path.GetDirectoryName(repository.DatabasePath)!,"alarm-delivery-state.json");
        state=File.Exists(statePath)?JsonSerializer.Deserialize<Dictionary<string,AlarmReceipt>>(File.ReadAllText(statePath)) ?? throw new InvalidDataException("Invalid local alarm state"):[];
    }
    internal void Invalidate()=>nextRead=DateTime.MinValue;
    private void Save() {
        var temp=statePath+".tmp";
        File.WriteAllText(temp,JsonSerializer.Serialize(state));
        if(File.Exists(statePath))File.Replace(temp,statePath,statePath+".previous",true);
        else File.Move(temp,statePath);
    }
    internal static bool AllowedByWindows() {
        try {
            using var key=Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\PushNotifications");
            if(key?.GetValue("ToastEnabled") is int enabled && enabled==0)return false;
            return SHQueryUserNotificationState(out var state)==0 && state==5;
        }
        catch(EntryPointNotFoundException){return false;}
    }
    [DllImport("shell32.dll")] private static extern int SHQueryUserNotificationState(out int state);
    internal void Tick(DateTime now) {
        var preferences=Path.Combine(Path.GetDirectoryName(statePath)!,"alarm-settings.json");
        var enabled=true;
        try {
            if(File.Exists(preferences)) {
                using var config=JsonDocument.Parse(File.ReadAllText(preferences));
                enabled=config.RootElement.GetProperty("version").GetInt32()==1 && config.RootElement.GetProperty("enabled").GetBoolean();
            }
            var restore=Path.Combine(Path.GetDirectoryName(statePath)!,"restore-status.json");
            if(File.Exists(restore)) {using var status=JsonDocument.Parse(File.ReadAllText(restore));if(status.RootElement.GetProperty("state").GetString()=="applied")enabled=false;}
        } catch(Exception error) when(error is IOException or JsonException or KeyNotFoundException or InvalidOperationException) {enabled=false;}
        // Invalid device/recovery policy fails closed; retained files are never replaced.
        if(!enabled || (privacy.IsLocked() && privacy.SuppressLockedNotifications()) || File.Exists(Path.Combine(Path.GetDirectoryName(statePath)!,"pending-restore.json"))) {
            foreach(var window in windows.Values.ToArray())window.Close();return;
        }
        if(now>=nextRead || (now-lastTick).Duration()>TimeSpan.FromSeconds(5)) {
            plans=repository.LoadAlarms(now);nextRead=now.AddSeconds(30);
            foreach(var key in windows.Keys.Where(k=>!plans.Any(p=>p.Key==k)).ToArray())windows[key].Close();
        }
        lastTick=now;
        if(!AllowedByWindows()){foreach(var window in windows.Values.ToArray())window.Close();return;}
        foreach(var alarm in plans) {
            if(windows.Count>0)break;
            state.TryGetValue(alarm.Key,out var previous);
            if(previous!=null && previous.State!="snoozed")continue;
            var due=previous?.Due ?? alarm.Due;
            if(due>now || now-due>TimeSpan.FromMinutes(5))continue;
            state[alarm.Key]=new(due,"ringing",now);Save(); // Persist before sound; failed writes never ring.
            var presented=privacy.IsLocked()?alarm with{Title="Todorbit alarm",Generic=true}:alarm;
            var window=new AlarmWindow(presented,palette(),minutes=>Finish(alarm,minutes),appExe==null?null:()=>Open(alarm));
            windows.Add(alarm.Key,window);window.Show();
        }
    }
    private void Finish(NativeAlarm alarm,int minutes) {
        state[alarm.Key]=new(DateTime.UtcNow.AddMinutes(minutes),minutes==0?"dismissed":"snoozed",DateTime.UtcNow);
        try {Save();} catch(IOException) {MessageBox.Show("The alarm stopped, but its action could not be saved. Keep your profile and check available disk space before retrying.","Todorbit alarm",MessageBoxButtons.OK,MessageBoxIcon.Warning);}
        finally {windows.Remove(alarm.Key);}
    }
    private void Open(NativeAlarm alarm) {
        if(appExe==null || !File.Exists(appExe))return;
        var start=new ProcessStartInfo(appExe){UseShellExecute=false};
        start.ArgumentList.Add("--navigate");
        start.ArgumentList.Add(JsonSerializer.Serialize(new{version=1,kind=alarm.Kind,id=alarm.EntityId,nominalDate=alarm.Nominal,day=(alarm.StartsAt??alarm.Due).ToLocalTime().ToString("yyyy-MM-dd"),action="edit"}));
        Process.Start(start);
    }
    public void Dispose(){foreach(var window in windows.Values.ToArray())window.Close();}
}

internal sealed class AlarmWindow : Form {
    private readonly SoundPlayer sound;
    private readonly System.Windows.Forms.Timer timer;
    private readonly Action<int> finish;
    private int result;
    protected override bool ShowWithoutActivation=>true;
    internal AlarmWindow(NativeAlarm alarm,WidgetPalette palette,Action<int> finish,Action? open) {
        this.finish=finish;
        Text="Todorbit alarm";AutoScaleMode=AutoScaleMode.Dpi;ClientSize=new(440,230);
        MinimumSize=new(440,230);StartPosition=FormStartPosition.CenterScreen;
        BackColor=palette.Panel;ForeColor=palette.Foreground;Font=new Font("Segoe UI",11);
        TopMost=true;ShowInTaskbar=true;
        var layout=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new Padding(20),ColumnCount=1,RowCount=3};
        layout.Controls.Add(new Label{Text=alarm.Title,AutoSize=true,MaximumSize=new Size(390,0),Font=new Font(Font,FontStyle.Bold)},0,0);
        var remaining=alarm.StartsAt==null?(int?)null:(int)Math.Ceiling((alarm.StartsAt.Value-DateTime.UtcNow).TotalMinutes);
        var detail=alarm.Generic?"Open Todorbit to view details":remaining==null?"Alarm - "+alarm.Due.ToLocalTime().ToString("f"):remaining>0?$"Starts in {remaining} minutes.":remaining==0?"Scheduled start is now.":$"Scheduled start was {-remaining} minutes ago.";
        layout.Controls.Add(new Label{Text=detail,AutoSize=true},0,1);
        var actions=new FlowLayoutPanel{Dock=DockStyle.Fill,AutoSize=true,WrapContents=true};
        foreach(var minutes in new[]{0,5,10,15}) {
            var button=new Button{Text=minutes==0?"Dismiss":$"Snooze {minutes} min",AutoSize=true,AccessibleName=minutes==0?"Dismiss alarm":$"Snooze alarm for {minutes} minutes"};
            button.FlatStyle=FlatStyle.Flat;button.BackColor=palette.Panel;button.ForeColor=palette.Foreground;button.FlatAppearance.BorderColor=palette.Border;
            button.Click+=(_,_)=>{result=minutes;Close();};if(minutes==0)CancelButton=button;actions.Controls.Add(button);
        }
        var openButton=new Button{Text="Open item",AutoSize=true,Enabled=open!=null,FlatStyle=FlatStyle.Flat,BackColor=palette.Panel,ForeColor=palette.Foreground};openButton.FlatAppearance.BorderColor=palette.Border;openButton.Click+=(_,_)=>{open?.Invoke();Close();};actions.Controls.Add(openButton);
        layout.Controls.Add(actions,0,2);Controls.Add(layout);
        var path=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"Media",alarm.Sound switch{"ringtone"=>"Alarm02.wav","notification"=>"Windows Notify System Generic.wav",_=>"Alarm01.wav"});
        sound=File.Exists(path)?new SoundPlayer(path):new SoundPlayer(new MemoryStream(Tone()));
        timer=new System.Windows.Forms.Timer{Interval=Math.Clamp(alarm.Duration,15,120)*1000};
        timer.Tick+=(_,_)=>Close();
        Shown+=(_,_)=>{try{sound.PlayLooping();}catch(Exception){Text="Todorbit alarm - sound unavailable";}timer.Start();};
    }
    private static byte[] Tone() {
        const int rate=16000;var samples=new short[rate];
        for(var i=0;i<rate*3/5;i++)samples[i]=(short)(Math.Sin(i*2*Math.PI*880/rate)*6000);
        using var output=new MemoryStream();using var writer=new BinaryWriter(output);
        writer.Write("RIFF"u8);writer.Write(36+samples.Length*2);writer.Write("WAVEfmt "u8);writer.Write(16);writer.Write((short)1);writer.Write((short)1);writer.Write(rate);writer.Write(rate*2);writer.Write((short)2);writer.Write((short)16);writer.Write("data"u8);writer.Write(samples.Length*2);foreach(var sample in samples)writer.Write(sample);return output.ToArray();
    }
    protected override void OnFormClosed(FormClosedEventArgs e){sound.Stop();timer.Stop();sound.Dispose();timer.Dispose();finish(result);base.OnFormClosed(e);}
}
