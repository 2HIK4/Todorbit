using System.Globalization;

internal sealed partial class NativeDesktopWidgetHost {
  private RectangleF DatePrevious => new(16, ContentTop - 34, 32, 32);
  private RectangleF DateNext => new(LogicalClientWidth - 48, ContentTop - 34, 32, 32);
  private RectangleF DateToday => new(52, ContentTop - 34, LogicalClientWidth - 104, 32);
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
    if (hoverTarget == HitTarget.DatePrevious) {
      using var fill = new SolidBrush(Color.FromArgb(20, palette.Accent));
      FillRoundedRectangle(graphics, fill, DatePrevious, 6);
      using var outline = new Pen(palette.Accent, pressedTarget == HitTarget.DatePrevious ? 2 : 1);
      DrawRoundedRectangle(graphics, outline, DatePrevious, 6);
    } else if (hoverTarget == HitTarget.DateNext) {
      using var fill = new SolidBrush(Color.FromArgb(20, palette.Accent));
      FillRoundedRectangle(graphics, fill, DateNext, 6);
      using var outline = new Pen(palette.Accent, pressedTarget == HitTarget.DateNext ? 2 : 1);
      DrawRoundedRectangle(graphics, outline, DateNext, 6);
    }
    DrawCalendarArrow(graphics, DatePrevious, -1, false, text.Color);
    DrawCalendarArrow(graphics, DateNext, 1, false, text.Color);
    var label = (selectedDate == DateTime.Today ? "Today, " : "") + selectedDate.ToString(selectedDate.Year == DateTime.Today.Year ? "ddd, MMM d" : "ddd, MMM d, yyyy", CultureInfo.CurrentCulture);
    if (hoverTarget == HitTarget.DateToday) {
      using var fill = new SolidBrush(Color.FromArgb(16, palette.Accent));
      FillRoundedRectangle(graphics, fill, DateToday, 6);
      using var outline = new Pen(Color.FromArgb(120, palette.Accent), pressedTarget == HitTarget.DateToday ? 2 : 1);
      DrawRoundedRectangle(graphics, outline, DateToday, 6);
    }
    DrawText(graphics, label, font, text, DateToday, format, "header");
  }
}
