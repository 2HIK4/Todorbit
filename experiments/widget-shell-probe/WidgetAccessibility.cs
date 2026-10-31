using System.Runtime.InteropServices;

internal sealed partial class NativeDesktopWidgetHost
{
    private WidgetAccessibleRoot? accessibleRoot;
    private int keyboardIndex = -1;
    private sealed record AccessibleAction(string Name, RectangleF Bounds, Action Invoke, bool Selected = false);
    private List<AccessibleAction> AccessibleActions()
    {
        var items = new List<AccessibleAction>();
        if (configuration.ShowOpenButton) items.Add(new("Open Todorbit", OpenRect, () => OpenMainApp()));
        if (privacy.IsLocked()) { items.Add(new("Unlock in Todorbit", AddRect, () => OpenMainApp())); return items; }
        if (calendar)
        {
            items.Add(new("Previous month", MonthPrevious, () => CalendarClick(Center(MonthPrevious))));
            items.Add(new("Next month", MonthNext, () => CalendarClick(Center(MonthNext))));
            items.Add(new("Return to today", MonthToday, () => CalendarClick(Center(MonthToday))));
            for (var i = 0; i < CalendarDays; i++)
            {
                var cell = CalendarCell(i); var date = CalendarGridStart.AddDays(i);
                var count = calendarItems.Count(x => x.Day == date);
                items.Add(new($"{date:D}, {count} scheduled items", cell, () => CalendarClick(Center(cell)), date == selectedDate));
            }
            var agenda = SelectedAgenda.Skip(agendaOffset).Take(AgendaVisibleRows).ToArray();
            for(var i=0;i<agenda.Length;i++) {
                var item=agenda[i];
                var bounds=AgendaRowBounds(i);
                items.Add(new($"Inspect {item.Title}, {AgendaMetadata(item)}",bounds,()=>ShowCalendarItem(item)));
            }
        }
        else
        {
            foreach (var view in VisibleViews) items.Add(new(ViewLabel(view), ViewRect(view), () => SetView(view), view == settings.View));
            for (var i = scrollOffset; i < Math.Min(tasks.Count, scrollOffset + VisibleTaskRows); i++)
            {
                var task = tasks[i]; var visible = i - scrollOffset;
                items.Add(new("Complete " + task.Title, CheckboxRect(visible), () => { RunAction(() => repository.CompleteTask(task.Id, task.UpdatedAt)); RefreshTasks(); }));
                items.Add(new("Edit " + task.Title, TaskRowRect(visible), () => OpenTaskEditor(task)));
            }
            items.Add(new("Add a task to " + ViewLabel(settings.View), AddRect, () => OpenQuickAdd()));
        }
        items.Add(new("Edit This Widget", new RectangleF(0, 0, 14, LogicalClientHeight), OpenWidgetSettings));
        return items;
    }
    private static PointF Center(RectangleF bounds) => new(bounds.X + bounds.Width / 2, bounds.Y + bounds.Height / 2);
    private Rectangle AccessibleBounds(RectangleF bounds)
    {
        Native.GetWindowRect(Handle, out var screen);
        return new(screen.Left + (int)(bounds.X * scale), screen.Top + (int)(bounds.Y * scale),
          (int)(bounds.Width * scale), (int)(bounds.Height * scale));
    }
    private bool KeyboardCommand(Keys key)
    {
        if(calendar && key is Keys.PageDown or Keys.PageUp) { Scroll(key==Keys.PageDown?1:-1);return true; }
        if (key == Keys.Apps || key == Keys.F10 && Control.ModifierKeys.HasFlag(Keys.Shift)) { ShowContextMenu(); return true; }
        var actions = AccessibleActions();
        if (key == Keys.Tab && actions.Count > 0)
        {
            keyboardIndex = (keyboardIndex + (Control.ModifierKeys.HasFlag(Keys.Shift) ? -1 : 1) + actions.Count) % actions.Count;
            Present("keyboard-focus"); return true;
        }
        if ((key is Keys.Enter or Keys.Space) && keyboardIndex >= 0 && keyboardIndex < actions.Count) { actions[keyboardIndex].Invoke(); return true; }
        return false;
    }
    private void DrawKeyboardFocus(Graphics graphics)
    {
        var items = AccessibleActions();
        if (keyboardIndex < 0 || keyboardIndex >= items.Count || Native.GetFocus() != Handle) return;
        using var pen = new Pen(palette.Accent, 2) { DashStyle = System.Drawing.Drawing2D.DashStyle.Dot };
        var r = items[keyboardIndex].Bounds; r.Inflate(-2, -2); DrawRoundedRectangle(graphics, pen, r, 4);
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
        public override AccessibleStates State => AccessibleStates.Focusable | (action.Selected ? AccessibleStates.Selected : AccessibleStates.None);
        public override Rectangle Bounds => host.AccessibleBounds(action.Bounds);
        public override string? DefaultAction => "Activate";
        public override void DoDefaultAction() => action.Invoke();
        public override void Select(AccessibleSelection flags) { host.keyboardIndex = index; Native.SetFocus(host.Handle); host.Present("accessible-focus"); }
    }
    [DllImport("oleacc.dll")]
    private static extern nint LresultFromObject(ref Guid id, nint wParam, [MarshalAs(UnmanagedType.Interface)] object accessible);
}
