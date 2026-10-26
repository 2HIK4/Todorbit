// Geometry is shared by painting, hit-testing and accessibility. At compact sizes
// the month prioritizes dates; additional space reveals actual scheduled content.
internal sealed record CalendarWidgetLayout(RectangleF Grid, RectangleF Agenda,
    float RowHeight, float TextScale)
{
    internal const float Gap = 12;
    internal int VisibleAgendaRows => Math.Max(1, (int)((Agenda.Height - 36) / RowHeight));
    internal RectangleF AgendaRow(int index) => new(Agenda.X + 8,
        Agenda.Y + 36 + index * RowHeight, Agenda.Width - 16, RowHeight);
    internal RectangleF Cell(int index) => new(Grid.X + index % 7 * Grid.Width / 7,
        Grid.Y + index / 7 * Grid.Height / 6, Grid.Width / 7, Grid.Height / 6);
    internal static CalendarWidgetLayout Create(SizeF size, float top, float scale, bool fullMonth)
    {
        var available = new RectangleF(16, top + 82, size.Width - 32, size.Height - top - 98);
        var rowHeight = Math.Max(40, 36 * scale);
        var sideBySide = size.Width >= 740 && available.Height >= 240;
        RectangleF grid, agenda;
        if (sideBySide)
        {
            var agendaWidth = Math.Clamp(available.Width * .32f, 240, 340);
            var gridWidth = available.Width - agendaWidth - Gap;
            var height = fullMonth ? available.Height : Math.Min(available.Height, 300 * scale);
            var width = fullMonth ? gridWidth : Math.Min(gridWidth, 448 * scale);
            grid = new(available.X + (gridWidth - width) / 2, available.Y, width, height);
            agenda = new(available.Right - agendaWidth, available.Y, agendaWidth, available.Height);
        }
        else
        {
            var agendaMinimum = 36 + rowHeight;
            var gridHeight = fullMonth ? Math.Max(132, available.Height - agendaMinimum - Gap)
                : Math.Min(264 * scale, Math.Max(132, available.Height * .60f));
            gridHeight = Math.Min(gridHeight, available.Height - agendaMinimum - Gap);
            var gridWidth = fullMonth ? available.Width : Math.Min(available.Width, 448 * scale);
            grid = new(available.X + (available.Width - gridWidth) / 2, available.Y, gridWidth, gridHeight);
            agenda = new(available.X, grid.Bottom + Gap, available.Width, available.Bottom - grid.Bottom - Gap);
        }
        return new(grid, agenda, rowHeight, scale);
    }
    internal int CellPreviewCapacity(bool fullMonth)
    {
        if (!fullMonth || Grid.Width / 7 < 68 * TextScale) return 0;
        return Math.Max(0, (int)((Grid.Height / 6 - 28 * TextScale) / (18 * TextScale)));
    }
    internal static (int Entries, int Remaining) PreviewCount(int total, int capacity)
    {
        if (total <= capacity) return (total, 0);
        var entries = Math.Max(0, capacity - 1);
        return (entries, total - entries);
    }
}
