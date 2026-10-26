internal sealed partial class NativeDesktopWidgetHost
{
    internal static void VerifyCalendarBehavior(LifeManagerWidgetRepository repository)
    {
        foreach (var textScale in new[] { 1f, 1.3f, 1.6f })
        foreach (var header in new[] { false, true })
        foreach (var size in new[] { WidgetGeometry.MinimumSize(true, textScale), new Size(560, 640), new Size(980, 620), new Size(420, 800) })
        {
            var config = new WidgetConfiguration { TextScale = textScale, ShowTitle = header, ShowOpenButton = header };
            using var host = new NativeDesktopWidgetHost(repository, config, true, size, WidgetPalette.Dark);
            host.ValidateLayout();
            if (host.CalendarGrid.Width / 7 < 36 || host.CalendarGrid.Height / 6 < 20 || host.AgendaVisibleRows < 1)
                throw new InvalidOperationException("Calendar minimum size loses readable date or agenda capacity.");
            for (var i = 0; i < host.CalendarDays; i++)
            {
                var hit = host.CalendarHitTest(Center(host.CalendarCell(i)));
                if (hit.Target != HitTarget.CalendarDate || hit.Index != i)
                    throw new InvalidOperationException("Calendar cell hit testing is not aligned with its painted date.");
            }
            using var image = RenderPreview(repository, config, true, size, WidgetPalette.Dark);
        }
        foreach (var weeks in new[] {4, 5, 6}) {
            var normal = CalendarWidgetLayout.Create(new SizeF(420, 500), 50, 1, weeks);
            var tall = CalendarWidgetLayout.Create(new SizeF(420, 750), 50, 1, weeks);
            if (Math.Abs(normal.Grid.Height - tall.Grid.Height) > .1f || tall.Agenda.Height - normal.Agenda.Height < 249)
                throw new InvalidOperationException("Extra height must grow the agenda, not the month cells.");
        }
        using var calendar = new NativeDesktopWidgetHost(repository, new WidgetConfiguration(), true, new Size(980, 620), WidgetPalette.Dark);
        calendar.calendarMonth = new DateTime(2026, 10, 1); calendar.LoadCalendar();
        var selectedIndex = (new DateTime(2026, 10, 26) - calendar.CalendarGridStart).Days;
        calendar.agendaOffset = 2;
        if (!calendar.CalendarClick(Center(calendar.CalendarCell(selectedIndex))) || calendar.selectedDate != new DateTime(2026, 10, 26) || calendar.agendaOffset != 0)
            throw new InvalidOperationException("Date selection does not reset and update the selected-day agenda.");
        if (!calendar.SelectedAgenda.Any(item => item.Kind == "Task") || !calendar.SelectedAgenda.Any(item => item.Kind == "Session") || !calendar.SelectedAgenda.Any(item => item.Kind == "Event"))
            throw new InvalidOperationException("Selected-day agenda lost the distinction among planned tasks, sessions and events.");
        calendar.calendarItems = Enumerable.Range(0, 20).Select(i => calendar.SelectedAgenda.First() with { Title = $"Item {i}" }).ToArray();
        if (calendar.SelectedAgenda.Length != 20) throw new InvalidOperationException("Agenda items were truncated.");
        calendar.Scroll(100);
        if (calendar.agendaOffset != 20 - calendar.AgendaVisibleRows) throw new InvalidOperationException("Agenda cannot scroll to its final item.");
        calendar.Scroll(-100);
        if (calendar.agendaOffset != 0) throw new InvalidOperationException("Agenda cannot return to its first item.");
        calendar.ScrollAt(Center(calendar.CalendarGrid), 1);
        if (calendar.agendaOffset != 0) throw new InvalidOperationException("Wheel over the grid scrolled the agenda.");
        calendar.ScrollAt(Center(calendar.AgendaRect), 1);
        if (calendar.agendaOffset != 1 || calendar.selectedDate != new DateTime(2026,10,26))
            throw new InvalidOperationException("Agenda wheel did not scroll independently of date selection.");
        calendar.calendarMonth = new DateTime(2026, 2, 1); calendar.calendarWeekStart = 7;
        if (calendar.CalendarWeeks != 4) throw new InvalidOperationException("Four-week month geometry failed.");
        calendar.calendarMonth = new DateTime(2026, 8, 1);
        if (calendar.CalendarWeeks != 6) throw new InvalidOperationException("Six-week month geometry failed.");
        using var details = new Form();
        calendar.calendarDetail = details;
        calendar.Dispose();
        if (!details.IsDisposed) throw new InvalidOperationException("Closing Calendar left schedule details open.");
    }
}
