using System.Globalization;
using System.Text.Json;

internal sealed partial class NativeDesktopWidgetHost
{
    private DateTime calendarMonth = new(DateTime.Today.Year, DateTime.Today.Month, 1);
    private DateTime selectedDate = DateTime.Today;
    private IReadOnlyList<WidgetCalendarItem> calendarItems = [];
    private int calendarWeekStart = 7;
    private int agendaOffset;
    private bool splittingCalendar;
    private RectangleF CalendarDivider => new(CalendarGrid.X,CalendarGrid.Bottom,CalendarGrid.Width,CalendarWidgetLayout.Gap);
    private void UpdateCalendarSplit(PointF point) {
      var available = AgendaRect.Bottom - CalendarGrid.Top - CalendarWidgetLayout.Gap;
      configuration.CalendarSplit = Math.Clamp((point.Y - CalendarGrid.Top) / Math.Max(1,available),.2f,.8f);
      Present("calendar-split",updateNow:false);
    }
    private int CalendarWeeks => Math.Max(4, (int)Math.Ceiling(((calendarMonth - CalendarGridStart).Days + DateTime.DaysInMonth(calendarMonth.Year, calendarMonth.Month)) / 7d));
    private int CalendarDays => CalendarWeeks * 7;
    private float CalendarTop => ContentTop;
    private CalendarWidgetLayout CalendarLayout => CalendarWidgetLayout.Create(
        new SizeF(LogicalClientWidth, LogicalClientHeight), CalendarTop, configuration.TextScale, CalendarWeeks, configuration.CalendarSplit);
    private RectangleF CalendarGrid => CalendarLayout.Grid;
    private RectangleF AgendaRect => CalendarLayout.Agenda;
    private RectangleF CalendarCell(int index) => CalendarLayout.Cell(index);
    private int AgendaVisibleRows => CalendarLayout.VisibleAgendaRows;
    private RectangleF AgendaRowBounds(int index) => CalendarLayout.AgendaRow(index);
    private DateTime CalendarGridStart => CalendarWidgetDates.GridStart(calendarMonth, calendarWeekStart);
    private RectangleF MonthPrevious => new(16, CalendarTop, 32, 32);
    private RectangleF MonthNext => new(LogicalClientWidth - 48, CalendarTop, 32, 32);
    private RectangleF MonthToday => new(LogicalClientWidth / 2f - 42, CalendarTop + 34, 84, 28);
    private WidgetCalendarItem[] SelectedAgenda => calendarItems.Where(item => item.Day == selectedDate).ToArray();

    internal void AdvanceToday(DateTime previous)
    {
        if (!calendar || selectedDate != previous) return;
        selectedDate = DateTime.Today;
        if (calendarMonth.Year == previous.Year && calendarMonth.Month == previous.Month)
            calendarMonth = new(selectedDate.Year, selectedDate.Month, 1);
        agendaOffset = 0;
    }
    private RectangleF CalendarControl(int index) => index switch
    {
        0 => MonthPrevious, 1 => MonthNext, _ => MonthToday,
    };
    private (HitTarget Target, int Index) CalendarHitTest(PointF point)
    {
        for (var i = 0; i < 3; i++) if (CalendarControl(i).Contains(point)) return (HitTarget.CalendarControl, i);
        for (var i = 0; i < CalendarDays; i++) if (CalendarCell(i).Contains(point)) return (HitTarget.CalendarDate, i);
        var agenda = SelectedAgenda;
        for (var i = 0; i < AgendaVisibleRows; i++)
            if (AgendaRowBounds(i).Contains(point) && i + agendaOffset < agenda.Length)
                return (HitTarget.CalendarAgenda, i + agendaOffset);
        return (HitTarget.None, -1);
    }
    private void ShowCalendarTooltip(HitTarget target, int index)
    {
        RectangleF bounds; string label;
        if (target == HitTarget.CalendarControl)
        {
            bounds = CalendarControl(index);
            label = index switch { 0 => "Previous month", 1 => "Next month", _ => "Return to today" };
        }
        else if (target == HitTarget.CalendarDate && index >= 0 && index < CalendarDays)
        {
            bounds = CalendarCell(index); var date = CalendarGridStart.AddDays(index);
            label = $"{date:D} · {calendarItems.Count(item => item.Day == date)} scheduled items. Select to inspect the agenda.";
        }
        else if (target == HitTarget.CalendarAgenda && index >= 0 && index < SelectedAgenda.Length)
        {
            var item = SelectedAgenda[index]; bounds = AgendaRowBounds(index - agendaOffset);
            label = $"{item.Title}\n{AgendaMetadata(item)}";
        }
        else return;
        openTooltip.Show(label, this, new Point(Pixel((int)bounds.X), Pixel((int)bounds.Bottom + 4)), 3000);
    }
    private void LoadCalendar()
    {
        calendarWeekStart = 7;
        var appearance = new AppearanceSettingsStore().Load();
        if (appearance.Additional?.TryGetValue("firstWeekday", out var week) == true && week.ValueKind == JsonValueKind.Number && week.TryGetInt32(out var day)) calendarWeekStart = day is >= 1 and <= 7 ? day : 7;
        calendarItems = repository.LoadCalendarItems(CalendarGridStart, CalendarGridStart.AddDays(42));
        var preference = Path.Combine(AppDataPaths.ActiveDirectory, "calendar-settings.json");
        try
        {
            if (!File.Exists(preference)) return;
            using var json = JsonDocument.Parse(File.ReadAllText(preference));
            if (json.RootElement.ValueKind == JsonValueKind.Object && json.RootElement.TryGetProperty("content", out var content) && content.ValueKind == JsonValueKind.String)
            {
                if (content.GetString() == "tasksOnly") calendarItems = calendarItems.Where(i => i.Kind != "Event").ToList();
                if (content.GetString() == "eventsOnly") calendarItems = calendarItems.Where(i => i.Kind == "Event").ToList();
            }
        }
        catch (Exception error) when (error is IOException or JsonException)
        {
            // Optional preference files may be observed while being copied.
        }
    }
    private static string ItemTime(WidgetCalendarItem item) => item.Time.Trim().TrimEnd('·').Trim();
    private static string AgendaMetadata(WidgetCalendarItem item)
    {
        var time = ItemTime(item);
        var kind = item.Kind == "Task" ? "Planned task" : item.Kind == "Session" ? "Work session" : "Event";
        return $"{kind}{(time.Length > 0 ? " · " + time : "")}{(item.Cancelled ? " · Cancelled" : "")}";
    }
    private void DrawCalendar(Graphics g, Font font, Font small)
    {
        using var text = new SolidBrush(SurfaceText("shell"));
        using var muted = new SolidBrush(SurfaceText("shell", true));
        using var center = CenterFormat();
        using var ellipsis = new StringFormat { Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap, LineAlignment = StringAlignment.Center };
        using var monthFont = new Font("Segoe UI Semibold", 14 * configuration.TextScale, FontStyle.Regular, GraphicsUnit.Pixel);
        DrawText(g, calendarMonth.ToString("MMMM yyyy"), monthFont, text, new RectangleF(52, CalendarTop, LogicalClientWidth - 104, 32), center, "shell");
        using (var todayFill = new SolidBrush(Color.FromArgb(32, palette.Accent))) FillRoundedRectangle(g, todayFill, MonthToday, 8);
        DrawText(g, "Today", small, text, MonthToday, center, "shell");
        DrawCalendarArrow(g, MonthPrevious, -1, false, text.Color);
        DrawCalendarArrow(g, MonthNext, 1, false, text.Color);
        if (hoverTarget == HitTarget.CalendarControl)
        {
            using var outline = new Pen(palette.Accent, pressedTarget == HitTarget.CalendarControl ? 2 : 1);
            DrawRoundedRectangle(g, outline, CalendarControl(hoverTask), 6);
        }
        PaintSurface(g, "content", CalendarGrid, palette.Panel);
        for (var col = 0; col < 7; col++)
        {
            var day = (DayOfWeek)((calendarWeekStart + col) % 7);
            var label = configuration.TextScale > 1.2f || CalendarGrid.Width < 340
                ? CultureInfo.CurrentCulture.DateTimeFormat.GetShortestDayName(day)
                : CultureInfo.CurrentCulture.DateTimeFormat.GetAbbreviatedDayName(day);
            DrawText(g, label, small, muted, new RectangleF(CalendarGrid.X + col * CalendarGrid.Width / 7, CalendarGrid.Y - 20, CalendarGrid.Width / 7, 20), center, "shell");
        }
        var byDay = calendarItems.GroupBy(item => item.Day).ToDictionary(group => group.Key, group => group.ToArray());
        for (var i = 0; i < CalendarDays; i++)
        {
            var date = CalendarGridStart.AddDays(i); var r = CalendarCell(i); r.Inflate(-2, -2);
            PaintSurface(g, "calendarCell", r, palette.Panel);
            {
                // Quiet dividers preserve separate days without overriding saved opacity.
                using var border = new Pen(Color.FromArgb(85, palette.Border), 1);
                var inset = r; inset.Inflate(-.5f, -.5f); DrawRoundedRectangle(g, border, inset, 6);
            }
            if (date == selectedDate) PaintSurface(g, "selectedDate", r, palette.Accent, palette.Accent);
            if (date == DateTime.Today) PaintSurface(g, "today", r, palette.Accent, palette.Accent);
            var surface = date == selectedDate ? (date == DateTime.Today ? "selectedToday" : "selectedDate") : date == DateTime.Today ? "today" : "calendarCell";
            using var ink = new SolidBrush(SurfaceText(surface, date.Month != calendarMonth.Month));
            if (hoverTarget == HitTarget.CalendarDate && hoverTask == i)
            {
                using var pen = new Pen(palette.Accent, 1); var hover = r; hover.Inflate(-1, -1); DrawRoundedRectangle(g, pen, hover, 6);
            }
            var items = byDay.GetValueOrDefault(date) ?? [];
            DrawText(g, date.Day.ToString(CultureInfo.CurrentCulture), font, ink,
                new RectangleF(r.X, r.Y, r.Width, r.Height - (items.Length > 0 ? 7 : 0)), center, surface);
            var eventCount = CountCalendarEvents(items);
            DrawEventCount(g,eventCount,r,ink.Color);
            // Task/session shapes retain their independent meaning at the cell edge.
            foreach(var kind in items.Where(item=>item.Kind != "Event").Select(item=>item.Kind).Distinct().Take(2)) {
              var marker = items.First(item=>item.Kind==kind);
              DrawItemMarker(g,marker,new RectangleF(r.X+3+(kind=="Session"?6:0),r.Bottom-6,3,3),ink.Color);
            }

        }
        using(var grip = new Pen(palette.Muted,2)) g.DrawLine(grip,CalendarDivider.X+CalendarDivider.Width/2-16,CalendarDivider.Y+6,CalendarDivider.X+CalendarDivider.Width/2+16,CalendarDivider.Y+6);
        DrawCalendarAgenda(g, font, small, ellipsis);
    }
    internal static int CountCalendarEvents(IEnumerable<WidgetCalendarItem> items) => items.Where(item=>item.Kind=="Event" && !item.Cancelled).Select(item=>$"{item.Id}:{item.NominalDate}").Distinct().Count();
    internal static int EventIndicator(int count) => count >= 4 ? -1 : Math.Max(0,count);
    private static void DrawEventCount(Graphics g,int count,RectangleF r,Color color) {
      using var ink = new SolidBrush(color);
      if(EventIndicator(count) == -1) g.FillRectangle(ink,r.X+r.Width/2-6,r.Bottom-6,12,2);
      else for(var n=0;n<count;n++) g.FillEllipse(ink,r.X+r.Width/2-(count*6-2)/2f+n*6,r.Bottom-7,4,4);
    }
    private static void DrawCalendarArrow(Graphics g, RectangleF bounds, int direction, bool vertical, Color color)
    {
        var x = bounds.X + bounds.Width / 2; var y = bounds.Y + bounds.Height / 2;
        using var pen = new Pen(color, 1.6f);
        PointF[] points = vertical ? [new(x - 4, y - direction * 2), new(x, y + direction * 2), new(x + 4, y - direction * 2)]
            : [new(x - direction * 3, y - 5), new(x + direction * 3, y), new(x - direction * 3, y + 5)];
        g.DrawLines(pen, points);
    }
    private static void DrawItemMarker(Graphics g, WidgetCalendarItem item, RectangleF bounds, Color color)
    {
        using var pen = new Pen(color, 1.2f);
        if (item.Kind == "Task") g.DrawRectangle(pen, bounds.X, bounds.Y, bounds.Width, bounds.Height);
        else if (item.Kind == "Session") { g.DrawEllipse(pen, bounds); g.DrawLine(pen, bounds.X + bounds.Width / 2, bounds.Y + 2, bounds.X + bounds.Width / 2, bounds.Y + bounds.Height / 2); }
        else { using var brush = new SolidBrush(color); g.FillEllipse(brush, bounds); }
    }
    private void DrawCalendarAgenda(Graphics g, Font font, Font small, StringFormat ellipsis)
    {
        PaintSurface(g, "agenda", AgendaRect, palette.Panel);
        using var text = new SolidBrush(SurfaceText("agenda"));
        using var muted = new SolidBrush(SurfaceText("agenda", true));
        var items = SelectedAgenda;
        agendaOffset = Math.Clamp(agendaOffset, 0, Math.Max(0, items.Length - AgendaVisibleRows));
        var overflow = items.Length > AgendaVisibleRows;
        DrawText(g, selectedDate.ToString("ddd, d MMM"), small, text,
            new RectangleF(AgendaRect.X + 8, AgendaRect.Y + 4, AgendaRect.Width - 16, 26), ellipsis, "agenda");
        if (overflow)
        {
            var track = new RectangleF(AgendaRect.Right - 7, AgendaRect.Y + 38, 3, AgendaRect.Height - 44);
            using var rail = new SolidBrush(Color.FromArgb(80, palette.Border));
            FillRoundedRectangle(g, rail, track, 2);
            var thumbHeight = Math.Max(14, track.Height * AgendaVisibleRows / items.Length);
            var offset = (track.Height - thumbHeight) * agendaOffset / Math.Max(1, items.Length - AgendaVisibleRows);
            using var thumb = new SolidBrush(SurfaceText("agenda", true));
            FillRoundedRectangle(g, thumb, new RectangleF(track.X, track.Y + offset, 3, thumbHeight), 2);
        }
        using (var divider = new Pen(Color.FromArgb(90, palette.Border)))
            g.DrawLine(divider, AgendaRect.X + 8, AgendaRect.Y + 32, AgendaRect.Right - 8, AgendaRect.Y + 32);
        for (var i = 0; i < Math.Min(AgendaVisibleRows, items.Length - agendaOffset); i++)
        {
            var item = items[i + agendaOffset]; var row = AgendaRowBounds(i);
            if (hoverTarget == HitTarget.CalendarAgenda && hoverTask == i + agendaOffset)
            {
                using var fill = new SolidBrush(Color.FromArgb(28, palette.Accent)); var hit = row; hit.Inflate(0, -1); FillRoundedRectangle(g, fill, hit, 6);
            }
            DrawItemMarker(g, item, new RectangleF(row.X + 3, row.Y + 7, 10, 10), item.Cancelled ? muted.Color : text.Color);
            using var itemFont = new Font(font, item.Cancelled ? FontStyle.Strikeout : FontStyle.Regular);
            DrawText(g, item.Title, itemFont, text, new RectangleF(row.X + 21, row.Y, row.Width - 24, row.Height * .55f), ellipsis, "agenda");
            DrawText(g, AgendaMetadata(item), small, muted, new RectangleF(row.X + 21, row.Y + row.Height * .52f, row.Width - 24, row.Height * .45f), ellipsis, "agenda");
        }
        if (items.Length == 0) DrawText(g, "Nothing scheduled", small, muted, AgendaRowBounds(0), ellipsis, "agenda");
    }
    private bool CalendarClick(PointF point)
    {
        if (configuration.ShowOpenButton && OpenRect.Contains(point)) return false;
        if (MonthPrevious.Contains(point) || MonthNext.Contains(point))
        {
            if (calendarMonth.Year <= 1 && MonthPrevious.Contains(point) || calendarMonth.Year >= 9998 && MonthNext.Contains(point)) return true;
            calendarMonth = calendarMonth.AddMonths(MonthPrevious.Contains(point) ? -1 : 1); selectedDate = calendarMonth; agendaOffset = 0; RefreshTasks(); return true;
        }
        if (MonthToday.Contains(point)) { selectedDate = DateTime.Today; calendarMonth = new(selectedDate.Year, selectedDate.Month, 1); agendaOffset = 0; RefreshTasks(); return true; }
        for (var i = 0; i < CalendarDays; i++) if (CalendarCell(i).Contains(point))
        {
            selectedDate = CalendarGridStart.AddDays(i); agendaOffset = 0; Present("calendar-date"); return true;
        }
        var hit = CalendarHitTest(point);
        if (hit.Target == HitTarget.CalendarAgenda)
        {
            ShowCalendarItem(SelectedAgenda[hit.Index]); return true;
        }
        return false;
    }
    private void ShowCalendarItem(WidgetCalendarItem item)
    {
        if (privacy.IsLocked()) return;
        OpenNavigation(item.Kind.ToLowerInvariant(), item.Kind == "Task" ? item.TaskId! : item.Id, item.Day.ToString("yyyy-MM-dd"),item.NominalDate);
    }
}

internal static class CalendarWidgetDates
{
    internal static DateTime GridStart(DateTime month, int firstWeekday)
    {
        var first = new DateTime(month.Year, month.Month, 1);
        var offset = ((int)first.DayOfWeek - firstWeekday + 7) % 7;
        return first.Ticks < offset * TimeSpan.TicksPerDay ? DateTime.MinValue : first.AddDays(-offset);
    }
}
