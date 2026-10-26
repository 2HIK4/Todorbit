internal sealed partial class NativeDesktopWidgetHost
{
    internal static void VerifyCalendarBehavior(LifeManagerWidgetRepository repository)
    {
        foreach (var mode in new[] { "compactAgenda", "fullMonth" })
        foreach (var textScale in new[] { 1f, 1.3f, 1.6f })
        foreach (var header in new[] { false, true })
        foreach (var size in new[] { WidgetGeometry.MinimumSize(true, textScale), new Size(560, 640), new Size(980, 620), new Size(420, 800) })
        {
            var config = new WidgetConfiguration { CalendarPresentation = mode, TextScale = textScale, ShowTitle = header, ShowOpenButton = header };
            using var host = new NativeDesktopWidgetHost(repository, config, true, size, WidgetPalette.Dark);
            host.ValidateLayout();
            if (host.CalendarGrid.Width / 7 < 36 || host.CalendarGrid.Height / 6 < 20 || host.AgendaVisibleRows < 1)
                throw new InvalidOperationException("Calendar minimum size loses readable date or agenda capacity.");
            for (var i = 0; i < 42; i++)
            {
                var hit = host.CalendarHitTest(Center(host.CalendarCell(i)));
                if (hit.Target != HitTarget.CalendarDate || hit.Index != i)
                    throw new InvalidOperationException("Calendar cell hit testing is not aligned with its painted date.");
            }
            using var image = RenderPreview(repository, config, true, size, WidgetPalette.Dark);
        }
        var large = CalendarWidgetLayout.Create(new SizeF(980, 700), 50, 1, true);
        var compact = CalendarWidgetLayout.Create(new SizeF(300, 360), 50, 1, true);
        if (large.CellPreviewCapacity(true) < 2 || compact.CellPreviewCapacity(true) != 0)
            throw new InvalidOperationException("Monthly content capacity does not adapt to available space.");
        if (CalendarWidgetLayout.PreviewCount(5, 3) != (2, 3) || CalendarWidgetLayout.PreviewCount(2, 3) != (2, 0))
            throw new InvalidOperationException("Monthly overflow count omits scheduled items.");
        using var calendar = new NativeDesktopWidgetHost(repository, new WidgetConfiguration { CalendarPresentation = "fullMonth" }, true, new Size(980, 620), WidgetPalette.Dark);
        calendar.calendarMonth = new DateTime(2026, 10, 1); calendar.LoadCalendar();
        var selectedIndex = (new DateTime(2026, 10, 26) - calendar.CalendarGridStart).Days;
        calendar.agendaOffset = 2;
        if (!calendar.CalendarClick(Center(calendar.CalendarCell(selectedIndex))) || calendar.selectedDate != new DateTime(2026, 10, 26) || calendar.agendaOffset != 0)
            throw new InvalidOperationException("Date selection does not reset and update the selected-day agenda.");
        if (!calendar.SelectedAgenda.Any(item => item.Kind == "Task") || !calendar.SelectedAgenda.Any(item => item.Kind == "Session") || !calendar.SelectedAgenda.Any(item => item.Kind == "Event"))
            throw new InvalidOperationException("Selected-day agenda lost the distinction among planned tasks, sessions and events.");
        using var details = new Form();
        calendar.calendarDetail = details;
        calendar.Dispose();
        if (!details.IsDisposed) throw new InvalidOperationException("Closing Calendar left schedule details open.");
    }
}
