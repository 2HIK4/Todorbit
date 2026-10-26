// Bounded geometry shared by painting, hit testing and accessibility.
internal sealed record CalendarWidgetLayout(RectangleF Grid, RectangleF Agenda,
    float RowHeight, float TextScale, int Weeks)
{
    internal const float Gap = 12;
    internal int VisibleAgendaRows => Math.Max(1, (int)((Agenda.Height - 36) / RowHeight));
    internal RectangleF AgendaRow(int index) => new(Agenda.X + 8,
        Agenda.Y + 36 + index * RowHeight, Agenda.Width - 24, RowHeight);
    internal RectangleF Cell(int index) => new(Grid.X + index % 7 * Grid.Width / 7,
        Grid.Y + index / 7 * Grid.Height / Weeks, Grid.Width / 7, Grid.Height / Weeks);
    internal static CalendarWidgetLayout Create(SizeF size, float top, float scale, int weeks = 6)
    {
        var available = new RectangleF(16, top + 82, size.Width - 32, size.Height - top - 98);
        var rowHeight = Math.Max(40, 36 * scale);
        var gridWidth = Math.Min(available.Width, 560 * scale);
        var cellHeight = Math.Clamp(gridWidth / 7 * .78f, 24 * scale, 46 * scale);
        var gridHeight = Math.Min(weeks * cellHeight, available.Height - 36 - rowHeight - Gap);
        var grid = new RectangleF(available.X + (available.Width - gridWidth) / 2,
            available.Y, gridWidth, gridHeight);
        var agenda = new RectangleF(available.X, grid.Bottom + Gap, available.Width,
            available.Bottom - grid.Bottom - Gap);
        return new(grid, agenda, rowHeight, scale, weeks);
    }
}
