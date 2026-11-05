using System.Globalization;

internal sealed partial class NativeDesktopWidgetHost {
  private RectangleF DatePrevious => new(16, ContentTop - 32, 32, 28);
  private RectangleF DateNext => new(LogicalClientWidth - 48, ContentTop - 32, 32, 28);
  private RectangleF DateToday => new(52, ContentTop - 32, LogicalClientWidth - 104, 28);
  private RectangleF DayPrevious => new(LogicalClientWidth / 2f - 80, CalendarTop + 34, 32, 28);
  private RectangleF DayNext => new(LogicalClientWidth / 2f + 48, CalendarTop + 34, 32, 28);

  private void MoveSelectedDate(int delta) {
    if (privacy.IsLocked()) return;
    if (delta < 0 && selectedDate.Year <= 1 || delta > 0 && selectedDate.Year >= 9998) return;
    selectedDate = selectedDate.AddDays(delta);
    calendarMonth = new(selectedDate.Year, selectedDate.Month, 1);
    scrollOffset = 0; agendaOffset = 0;
    RefreshTasks();
  }
  private void DrawDateNavigation(Graphics graphics, Font font) {
    using var text = new SolidBrush(SurfaceText("header"));
    using var format = CenterFormat();
    DrawText(graphics, "‹", font, text, DatePrevious, format, "header");
    DrawText(graphics, "›", font, text, DateNext, format, "header");
    var label = (selectedDate == DateTime.Today ? "Today, " : "") + selectedDate.ToString(selectedDate.Year == DateTime.Today.Year ? "ddd, MMM d" : "ddd, MMM d, yyyy", CultureInfo.CurrentCulture);
    DrawText(graphics, label, font, text, DateToday, format, "header");
  }
}
