using System.Runtime.InteropServices;

internal sealed partial class NativeDesktopWidgetHost
{
    private WidgetAccessibleRoot? accessibleRoot;
    private int keyboardIndex = -1;
    private sealed record AccessibleAction(string Name, RectangleF Bounds, Action Invoke, bool Selected = false, Action? EnsureVisible = null, bool Offscreen = false);
    private List<AccessibleAction> AccessibleActions()
    {
        var items = new List<AccessibleAction>();
        if (configuration.ShowOpenButton) items.Add(new("Open Todorbit", OpenRect, () => OpenMainApp()));
        if (privacy.IsLocked()) { items.Add(new("Unlock in Todorbit", AddRect, () => OpenMainApp())); return items; }
        if (calendar)
        {
            items.Add(new("Previous day", DayPrevious, () => MoveSelectedDate(-1)));
            items.Add(new("Next day", DayNext, () => MoveSelectedDate(1)));
            items.Add(new("Previous month", MonthPrevious, () => CalendarClick(Center(MonthPrevious))));
            items.Add(new("Next month", MonthNext, () => CalendarClick(Center(MonthNext))));
            items.Add(new("Return to today", MonthToday, () => CalendarClick(Center(MonthToday))));
            for (var i = 0; i < CalendarDays; i++)
            {
                var cell = CalendarCell(i); var date = CalendarGridStart.AddDays(i);
                var count = calendarItems.Count(x => x.Day == date);
                items.Add(new($"{date:D}, {count} scheduled items", cell, () => CalendarClick(Center(cell)), date == selectedDate));
            }
            for (var i = 0; i < SelectedAgenda.Length; i++)
            {
                var idx = i;
                var item = SelectedAgenda[idx];
                var bounds = AgendaRowBounds(idx);
                var visible = bounds.Bottom > AgendaViewport.Top && bounds.Top < AgendaViewport.Bottom;
                var clipped = visible ? RectangleF.Intersect(bounds, AgendaViewport) : RectangleF.Empty;
                items.Add(new($"Inspect {item.Title}, {AgendaMetadata(item)}", clipped, () => ShowCalendarItem(item), false, () => ScrollAgendaRowIntoView(idx), !visible));
            }
        }
        else
        {
            if (settings.View == WidgetTaskView.Today) {
              items.Add(new("Previous day", DatePrevious, () => MoveSelectedDate(-1)));
              items.Add(new("Next day", DateNext, () => MoveSelectedDate(1)));
              items.Add(new($"{selectedDate:D}. Return to today", DateToday, () => { selectedDate=DateTime.Today; RefreshTasks(); }));
            }
            foreach (var view in VisibleViews) items.Add(new(ViewLabel(view), ViewRect(view), () => SetView(view), view == settings.View));
            for (var i = 0; i < tasks.Count; i++)
            {
                var idx = i;
                var task = tasks[idx];
                var rowBounds = TaskRowRect(idx);
                var visible = rowBounds.Bottom > TaskViewport.Top && rowBounds.Top < TaskViewport.Bottom;
                var boxBounds = visible ? RectangleF.Intersect(CheckboxRect(idx), TaskViewport) : RectangleF.Empty;
                var clippedRow = visible ? RectangleF.Intersect(rowBounds, TaskViewport) : RectangleF.Empty;
                items.Add(new("Complete " + task.Title, boxBounds, () => { RunAction(() => repository.CompleteTask(task.Id, task.UpdatedAt)); RefreshTasks(); }, false, () => ScrollTaskRowIntoView(idx), !visible || boxBounds.IsEmpty));
                items.Add(new("Edit " + task.Title, clippedRow, () => OpenTaskEditor(task), false, () => ScrollTaskRowIntoView(idx), !visible));
            }
            items.Add(new("Add a task to " + ViewLabel(settings.View), AddRect, () => OpenQuickAdd()));
        }
        items.Add(new("Edit This Widget", new RectangleF(0, 0, 14, LogicalClientHeight), OpenWidgetSettings));
        return items;
    }
    private void ScrollTaskRowIntoView(int index)
    {
        if (index < 0 || index >= tasks.Count) return;
        var row = TaskRowRect(index);
        if (taskScroll.EnsureItemVisible(row.Top, row.Bottom, TaskViewport.Top, TaskViewport.Bottom, MaxTaskScrollPixels))
        {
            StopScrollTimer();
            Present("accessible-scroll", updateNow: false);
        }
    }
    private void ScrollAgendaRowIntoView(int index)
    {
        if (index < 0 || index >= SelectedAgenda.Length) return;
        var row = AgendaRowBounds(index);
        if (agendaScroll.EnsureItemVisible(row.Top, row.Bottom, AgendaViewport.Top, AgendaViewport.Bottom, MaxAgendaScrollPixels))
        {
            StopScrollTimer();
            Present("accessible-scroll", updateNow: false);
        }
    }
    private static PointF Center(RectangleF bounds) => new(bounds.X + bounds.Width / 2, bounds.Y + bounds.Height / 2);
    private Rectangle AccessibleBounds(RectangleF bounds)
    {
        if (bounds.IsEmpty || bounds.Width <= 0f || bounds.Height <= 0f) return Rectangle.Empty;
        Native.GetWindowRect(Handle, out var screen);
        return new(screen.Left + (int)(bounds.X * scale), screen.Top + (int)(bounds.Y * scale),
          (int)(bounds.Width * scale), (int)(bounds.Height * scale));
    }
    private bool KeyboardCommand(Keys key)
    {
        if (key is Keys.PageDown or Keys.PageUp) { Scroll(key == Keys.PageDown ? 1 : -1); return true; }
        if (key == Keys.Apps || key == Keys.F10 && Control.ModifierKeys.HasFlag(Keys.Shift)) { ShowContextMenu(); return true; }
        var actions = AccessibleActions();
        if (key == Keys.Tab && actions.Count > 0)
        {
            keyboardIndex = (keyboardIndex + (Control.ModifierKeys.HasFlag(Keys.Shift) ? -1 : 1) + actions.Count) % actions.Count;
            actions[keyboardIndex].EnsureVisible?.Invoke();
            Present("keyboard-focus"); return true;
        }
        if ((key is Keys.Enter or Keys.Space) && keyboardIndex >= 0 && keyboardIndex < actions.Count) { actions[keyboardIndex].Invoke(); return true; }
        return false;
    }
    private void DrawKeyboardFocus(Graphics graphics)
    {
        var items = AccessibleActions();
        if (keyboardIndex < 0 || keyboardIndex >= items.Count || Native.GetFocus() != Handle) return;
        var r = items[keyboardIndex].Bounds;
        if (r.IsEmpty || r.Width < 1f || r.Height < 1f) return;
        r.Inflate(-Math.Min(2f, r.Width * 0.25f), -Math.Min(2f, r.Height * 0.25f));
        if (r.Width < 1f || r.Height < 1f) return;
        using var pen = new Pen(palette.Accent, 2) { DashStyle = System.Drawing.Drawing2D.DashStyle.Dot };
        DrawRoundedRectangle(graphics, pen, r, 4);
    }
    [ComVisible(true)]
    private sealed class WidgetAccessibleRoot(NativeDesktopWidgetHost host) : AccessibleObject
    {
        public override string? Name { get => host.calendar ? "Todorbit Calendar Widget" : "Todorbit Tasks Widget"; set { } }
        public override AccessibleRole Role => AccessibleRole.Pane;
        public override Rectangle Bounds => host.AccessibleBounds(new RectangleF(0, 0, host.LogicalClientWidth, host.LogicalClientHeight));
        public override int GetChildCount() => host.AccessibleActions().Count;
        public override AccessibleObject? GetChild(int index)
        {
            var actions = host.AccessibleActions(); return index >= 0 && index < actions.Count ? new WidgetAccessibleAction(host, this, actions[index], index) : null;
        }
        public override AccessibleObject? HitTest(int x, int y)
        {
            for (var i = GetChildCount() - 1; i >= 0; i--) { var child = GetChild(i); if (child?.Bounds.Contains(x, y) == true) return child; }
            return Bounds.Contains(x, y) ? this : null;
        }
    }
    [ComVisible(true)]
    private sealed class WidgetAccessibleAction(NativeDesktopWidgetHost host, AccessibleObject parent, AccessibleAction action, int index) : AccessibleObject
    {
        public override string? Name { get => action.Name; set { } }
        public override AccessibleObject? Parent => parent;
        public override AccessibleRole Role => AccessibleRole.PushButton;
        public override AccessibleStates State => AccessibleStates.Focusable | (action.Selected ? AccessibleStates.Selected : AccessibleStates.None) | (action.Offscreen ? AccessibleStates.Offscreen : AccessibleStates.None);
        public override Rectangle Bounds => host.AccessibleBounds(action.Bounds);
        public override string? DefaultAction => "Activate";
        public override void DoDefaultAction() => action.Invoke();
        public override void Select(AccessibleSelection flags) { host.keyboardIndex = index; action.EnsureVisible?.Invoke(); Native.SetFocus(host.Handle); host.Present("accessible-focus"); }
    }
    [DllImport("oleacc.dll")]
    private static extern nint LresultFromObject(ref Guid id, nint wParam, [MarshalAs(UnmanagedType.Interface)] object accessible);
}
