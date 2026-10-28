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
        for(var count=0;count<=6;count++) if(EventIndicator(count)!=(count>=4?-1:count)) throw new InvalidOperationException("Event count indicator failed");
        var splitLayout=CalendarWidgetLayout.Create(new SizeF(400,700),30,1,6,.7f);
        var agendaLayout=CalendarWidgetLayout.Create(new SizeF(400,700),30,1,6,.3f);
        if(splitLayout.Grid.Height<=agendaLayout.Grid.Height || splitLayout.Agenda.Height<76) throw new InvalidOperationException("Calendar split constraints failed");
        foreach(var scale in new[] {1f,1.3f,1.6f}) foreach(var weeks in new[] {4,5,6}) foreach(var split in new[] {.2f,.5f,.8f}) {
          var layout=CalendarWidgetLayout.Create(WidgetGeometry.MinimumSize(true,scale),Math.Max(50,20*scale+26),scale,weeks,split);
          if(layout.Grid.Height/weeks < 28*scale-.01f || layout.Agenda.Height < 36+layout.RowHeight-.01f) throw new InvalidOperationException("Divider clips a date or agenda row at minimum size.");
        }
        for(var count=0;count<=6;count++) {
          var events=Enumerable.Range(0,count).Select(i=>new WidgetCalendarItem(DateTime.Today,"Event","Event",null,Id:$"event-{i}")).ToList();
          if(events.Count>0) events.Add(events[0]);
          events.Add(new(DateTime.Today,"Event","Cancelled",null,Cancelled:true,Id:"cancelled"));
          events.Add(new(DateTime.Today,"Task","Task","task-id",Id:"task-id"));
          if(CountCalendarEvents(events)!=count) throw new InvalidOperationException("Event counts included duplicates, cancelled events or tasks.");
        }
        foreach(var palette in new[] {WidgetPalette.Light,WidgetPalette.Dark}) {
          var config=new WidgetConfiguration();
          config.Surface("shell").Opacity=20;
          config.Surface("taskRow").Opacity=35; config.Surface("taskRow").TextColor="#FFFFFF";
          config.Surface("selectedNavigation").Opacity=75;config.Surface("selectedNavigation").TextColor="#000000";
          using var host=new NativeDesktopWidgetHost(repository,config,false,new Size(376,460),palette);
          if(host.SurfaceText("taskRow").A!=255 || host.SurfaceText("selectedNavigation").A!=255 || config.Surface("taskRow").Resolve(palette.Row).A!=89 || config.Surface("selectedNavigation").Resolve(palette.Accent).A!=191) throw new InvalidOperationException("Text/surface opacity inherited the shell alpha.");
        }
        var sent=NavigationActivation("test.exe","event","event-id","2026-10-28","2026-10-20");
        if(sent.ArgumentList[0]!="--navigate" || !sent.ArgumentList[1].Contains("event-id") || !sent.ArgumentList[1].Contains("2026-10-20")) throw new InvalidOperationException("Typed navigation lost its occurrence identity.");
        calendar.Dispose();
    }
}
