using System.Globalization;
using System.Text.Json;

internal sealed partial class NativeDesktopWidgetHost
{
    private DateTime calendarMonth = new(DateTime.Today.Year, DateTime.Today.Month, 1);
    private DateTime selectedDate = DateTime.Today;
    private IReadOnlyList<WidgetCalendarItem> calendarItems = [];
    private int calendarWeekStart = 7;
    private int agendaOffset;
    private float CalendarTop => ContentTop;
    private float CalendarGridHeight => Math.Clamp((LogicalClientHeight - CalendarTop - 100) * 0.68f, 112, 258);
    private RectangleF CalendarGrid => new(16, CalendarTop + 78, LogicalClientWidth - 32, CalendarGridHeight);
    private DateTime CalendarGridStart => CalendarWidgetDates.GridStart(calendarMonth, calendarWeekStart);
    private RectangleF CalendarCell(int i) => new(CalendarGrid.X + i % 7 * CalendarGrid.Width / 7,
      CalendarGrid.Y + i / 7 * CalendarGrid.Height / 6, CalendarGrid.Width / 7, CalendarGrid.Height / 6);
    private RectangleF AgendaRect => new(16, CalendarGrid.Bottom + 8, LogicalClientWidth - 32,
      Math.Max(24, LogicalClientHeight - CalendarGrid.Bottom - 24));
    private RectangleF MonthPrevious => new(16, CalendarTop, 30, 30);
    private RectangleF MonthNext => new(LogicalClientWidth - 46, CalendarTop, 30, 30);
    private RectangleF MonthToday => new(LogicalClientWidth / 2f - 45, CalendarTop + 30, 90, 26);
    internal void AdvanceToday(DateTime previous)
    {
        if (!calendar || selectedDate != previous) return;
        selectedDate = DateTime.Today;
        if (calendarMonth.Year == previous.Year && calendarMonth.Month == previous.Month)
            calendarMonth = new(selectedDate.Year, selectedDate.Month, 1);
        agendaOffset = 0;
    }
    private (HitTarget Target, int Index) CalendarHitTest(PointF point)
    {
        if (MonthPrevious.Contains(point)) return (HitTarget.CalendarControl, 0);
        if (MonthNext.Contains(point)) return (HitTarget.CalendarControl, 1);
        if (MonthToday.Contains(point)) return (HitTarget.CalendarControl, 2);
        for (var i = 0; i < 42; i++) if (CalendarCell(i).Contains(point)) return (HitTarget.CalendarDate, i);
        if(AgendaRect.Contains(point) && point.Y>=AgendaRect.Y+25) {
            var index=(int)((point.Y-AgendaRect.Y-25)/26)+agendaOffset;
            var items=calendarItems.Where(item=>item.Day==selectedDate).ToArray();
            if(index>=0 && index<items.Length && items[index].TaskId!=null)
                return (HitTarget.CalendarAgenda,index);
        }
        return (HitTarget.None,-1);
    }
    private void ShowCalendarTooltip(HitTarget target, int index)
    {
        RectangleF bounds; string label;
        if (target == HitTarget.CalendarControl)
        {
            bounds = index == 0 ? MonthPrevious : index == 1 ? MonthNext : MonthToday;
            label = index == 0 ? "Previous month" : index == 1 ? "Next month" : "Return to today";
        }
        else if (target == HitTarget.CalendarDate && index >= 0 && index < 42)
        {
            bounds = CalendarCell(index); var date = CalendarGridStart.AddDays(index);
            label = $"{date:D} · {calendarItems.Count(item => item.Day == date)} scheduled items";
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
            // Match the Flutter preference store's safe default. A subsequent
            // debounced file change retries a partially copied preference file.
        }
    }
    private void DrawCalendar(Graphics g, Font font, Font small)
    {
        using var text = new SolidBrush(SurfaceText("shell"));
        using var muted = new SolidBrush(SurfaceText("shell", true));
        using var center = CenterFormat();
        DrawText(g, calendarMonth.ToString("MMMM yyyy"), font, text, new RectangleF(50, CalendarTop, LogicalClientWidth - 100, 30), center, "shell");
        DrawText(g, "Today", small, text, MonthToday, center, "shell");
        if (hoverTarget == HitTarget.CalendarControl)
        {
            var bounds = hoverTask == 0 ? MonthPrevious : hoverTask == 1 ? MonthNext : MonthToday;
            using var outline = new Pen(palette.Accent, pressedTarget == HitTarget.CalendarControl ? 2 : 1); DrawRoundedRectangle(g, outline, bounds, 4);
        }
        var controlInk = SurfaceText("shell");
        if (configuration.ProtectText && NeedsTextBacking("shell", controlInk))
        {
            using var backing = new SolidBrush(palette.Panel);
            FillRoundedRectangle(g, backing, MonthPrevious, 4); FillRoundedRectangle(g, backing, MonthNext, 4);
            controlInk = palette.Foreground;
        }
        using (var p = new Pen(controlInk, 1.6f))
        {
            foreach (var direction in new[] { -1, 1 })
            {
                var r = direction < 0 ? MonthPrevious : MonthNext; var x = r.X + r.Width / 2; var y = r.Y + r.Height / 2;
                g.DrawLines(p, new PointF[] { new(x - direction * 3, y - 5), new(x + direction * 3, y), new(x - direction * 3, y + 5) });
            }
        }
        PaintSurface(g, "content", CalendarGrid, palette.Panel);
        for (var col = 0; col < 7; col++)
        {
            var day = (DayOfWeek)((calendarWeekStart + col) % 7);
            DrawText(g, CultureInfo.CurrentCulture.DateTimeFormat.GetAbbreviatedDayName(day), small, muted,
              new RectangleF(CalendarGrid.X + col * CalendarGrid.Width / 7, CalendarGrid.Y - 20, CalendarGrid.Width / 7, 20), center, "shell");
        }
        for (var i = 0; i < 42; i++)
        {
            var date = CalendarGridStart.AddDays(i); var r = CalendarCell(i); r.Inflate(-2, -2);
            PaintSurface(g, "calendarCell", r, palette.Panel);
            if (date == selectedDate) PaintSurface(g, "selectedDate", r, palette.Accent, palette.Accent);
            if (date == DateTime.Today) PaintSurface(g, "today", r, palette.Accent, palette.Accent);
            var cellSurface = date == selectedDate ? (date == DateTime.Today ? "selectedToday" : "selectedDate") : date == DateTime.Today ? "today" : "calendarCell";
            using var ink = new SolidBrush(SurfaceText(cellSurface, date.Month != calendarMonth.Month));
            if (hoverTarget == HitTarget.CalendarDate && hoverTask == i) { using var pen = new Pen(palette.Accent, 1); DrawRoundedRectangle(g, pen, r, 4); }
            if (date == selectedDate) { using var mark = new SolidBrush(ink.Color); g.FillEllipse(mark, r.X + 3, r.Y + 3, 3, 3); }
            if (date == DateTime.Today) { using var marker = new Pen(palette.Accent, 2); g.DrawLine(marker, r.X + r.Width / 2 - 4, r.Bottom - 2, r.X + r.Width / 2 + 4, r.Bottom - 2); }
            DrawText(g, date.Day.ToString(), font, ink, r, center, cellSurface);
            if (calendarItems.Any(item => item.Day == date)) g.FillEllipse(ink, r.X + r.Width / 2 - 2, r.Bottom - 5, 4, 3);
        }
        PaintSurface(g, "agenda", AgendaRect, palette.Panel);
        using var agendaText = new SolidBrush(SurfaceText("agenda"));
        using var agendaMuted = new SolidBrush(SurfaceText("agenda", true));
        DrawText(g, selectedDate.ToString("ddd, d MMM"), small, agendaText, new RectangleF(AgendaRect.X + 6, AgendaRect.Y + 4, AgendaRect.Width - 12, 20), surface: "agenda");
        var items = calendarItems.Where(i => i.Day == selectedDate).ToList();
        var visible = Math.Max(0, (int)((AgendaRect.Height - 27) / 26));
        agendaOffset = Math.Clamp(agendaOffset, 0, Math.Max(0, items.Count - visible));
        using var ellipsis = new StringFormat { Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap };
        for (var i = 0; i < Math.Min(visible, items.Count - agendaOffset); i++)
        {
            var item = items[i + agendaOffset];
            using var itemFont = new Font(font, item.Cancelled ? FontStyle.Strikeout : FontStyle.Regular);
            DrawText(g, $"{item.Kind} · {item.Time}{item.Title}{(item.Cancelled ? " (Cancelled)" : "")}", itemFont, agendaText,
              new RectangleF(AgendaRect.X + 6, AgendaRect.Y + 25 + i * 26, AgendaRect.Width - 12, 24), ellipsis, "agenda");
        }
        if (items.Count == 0) DrawText(g, "Nothing scheduled.", small, agendaMuted, new RectangleF(AgendaRect.X + 6, AgendaRect.Y + 25, AgendaRect.Width - 12, 24), surface: "agenda");
        if (items.Count > visible) DrawText(g, "Scroll for more", small, agendaMuted, new RectangleF(AgendaRect.Right - 100, AgendaRect.Y + 4, 94, 20), surface: "agenda");
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
        for (var i = 0; i < 42; i++) if (CalendarCell(i).Contains(point)) { selectedDate = CalendarGridStart.AddDays(i); agendaOffset = 0; Present("calendar-date"); return true; }
        if (AgendaRect.Contains(point))
        {
            var index = (int)((point.Y - AgendaRect.Y - 25) / 26) + agendaOffset;
            var items = calendarItems.Where(i => i.Day == selectedDate).ToList();
            if (point.Y >= AgendaRect.Y + 25 && index >= 0 && index < items.Count && items[index].TaskId is { } taskId) OpenMainApp(taskId);
            return true;
        }
        return false;
    }
}

internal static class CalendarWidgetDates
{
    internal static DateTime GridStart(DateTime month, int firstWeekday)
    {
        var first = new DateTime(month.Year, month.Month, 1);
        return first.AddDays(-(((int)first.DayOfWeek - firstWeekday + 7) % 7));
    }
}
