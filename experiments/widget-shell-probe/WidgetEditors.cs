using System.Globalization;
using System.Runtime.InteropServices;

// The desktop-attached HWND cannot own keyboard focus reliably. This short-lived,
// activatable top-level surface is aligned over the painted Quick Add field so the
// interaction remains visually inline without putting child controls in Explorer.
internal sealed class InlineQuickAddForm : Form {
  private readonly TextBox editor = new();
  private readonly Label feedback = new();
  private readonly Action<string> submit;

  internal InlineQuickAddForm(
      WidgetPalette palette, Rectangle bounds, string destination,
      Action<string> submit) {
    this.submit = submit;
    Text = "Quick Add - Todorbit";
    FormBorderStyle = FormBorderStyle.None;
    StartPosition = FormStartPosition.Manual;
    ShowInTaskbar = false;
    TopMost = false;
    Bounds = bounds;
    BackColor = palette.Panel;
    ForeColor = palette.Foreground;
    Font = new Font("Segoe UI", 9.5f);
    Padding = new Padding(1);
    KeyPreview = true;

    var plus = new Label {
      Text = "+",
      Font = new Font("Segoe UI Semibold", 15, FontStyle.Bold),
      ForeColor = palette.Accent,
      Location = new Point(8, 5),
      Size = new Size(24, 27),
      TextAlign = ContentAlignment.MiddleCenter,
    };
    editor.BorderStyle = BorderStyle.None;
    editor.PlaceholderText = "Add a task...";
    editor.BackColor = palette.Panel;
    editor.ForeColor = palette.Foreground;
    editor.Location = new Point(38, 10);
    editor.Size = new Size(Math.Max(80, Width - 132), 24);
    editor.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top;
    editor.AccessibleName = $"Add a task to {destination}";
    var destinationLabel = new Label {
      Text = destination,
      ForeColor = palette.Muted,
      Location = new Point(Width - 87, 7),
      Size = new Size(76, 28),
      Anchor = AnchorStyles.Top | AnchorStyles.Right,
      TextAlign = ContentAlignment.MiddleRight,
    };
    feedback.ForeColor = Color.FromArgb(205, 72, 72);
    feedback.Location = new Point(38, Height - 18);
    feedback.Size = new Size(Math.Max(80, Width - 48), 17);
    feedback.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom;
    feedback.Visible = false;
    editor.KeyDown += EditorKeyDown;
    editor.GotFocus += (_, _) => Invalidate();
    editor.LostFocus += (_, _) => Invalidate();
    Controls.AddRange([plus, editor, destinationLabel, feedback]);
    Paint += (_, eventArgs) => {
      using var pen = new Pen(ContainsFocus ? palette.Accent : palette.Border, 2);
      eventArgs.Graphics.DrawRectangle(pen, 1, 1, Width - 3, Height - 3);
    };
    Activated += (_, _) => Invalidate();
    Deactivate += (_, _) => {
      if (!IsDisposed) Close();
    };
  }

  private void EditorKeyDown(object? sender, KeyEventArgs eventArgs) {
    if (eventArgs.KeyCode == Keys.Escape) {
      eventArgs.SuppressKeyPress = true;
      Close();
      return;
    }
    if (eventArgs.KeyCode != Keys.Enter || eventArgs.Modifiers != Keys.None) return;
    eventArgs.SuppressKeyPress = true;
    var title = editor.Text.Trim();
    if (title.Length == 0) {
      feedback.Text = "Enter a task title.";
      feedback.Visible = true;
      Height = Math.Max(58, Height);
      System.Media.SystemSounds.Beep.Play();
      return;
    }
    try {
      submit(title);
      editor.Clear();
      DialogResult = DialogResult.OK;
      Close();
    } catch (Exception error) {
      feedback.Text = error.Message;
      feedback.Visible = true;
      Height = Math.Max(68, Height);
    }
  }

  protected override void OnShown(EventArgs eventArgs) {
    base.OnShown(eventArgs);
    Activate();
    editor.Focus();
  }
}

internal sealed class TaskEditorDialog : Form {
  private readonly LifeManagerWidgetRepository repository;
  private readonly WidgetTask original;
  private readonly TextBox title = new();
  private readonly TextBox notes = new();
  private readonly ComboBox status = new();
  private readonly ComboBox priority = new();
  private readonly ComboBox category = new();
  private readonly ComboBox project = new();
  private readonly DateTimePicker scheduled = new();
  private readonly DateTimePicker deadline = new();
  private readonly Label feedback = new();
  private readonly IReadOnlyList<WidgetChoice> projects;
  internal bool OpenFullDetails { get; private set; }

  internal TaskEditorDialog(
      LifeManagerWidgetRepository repository, WidgetTask task,
      WidgetPalette palette) {
    this.repository = repository;
    original = task;
    projects = repository.LoadProjects();
    Text = "Edit task - Todorbit";
    FormBorderStyle = FormBorderStyle.Sizable;
    StartPosition = FormStartPosition.Manual;
    ClientSize = new Size(480, 554);
    MinimumSize = new Size(390, 593);
    AutoScaleMode = AutoScaleMode.Dpi;
    MaximizeBox = false;
    MinimizeBox = false;
    ShowInTaskbar = true;
    BackColor = palette.Background;
    ForeColor = palette.Foreground;
    Font = new Font("Segoe UI", 9.5f);
    Padding = new Padding(18);

    var heading = LabelFor("Task details", 18, 15, 440, 28);
    heading.Font = new Font("Segoe UI Semibold", 15, FontStyle.Bold);
    AddLabeledControl("Title *", title, 18, 58, 444, 31);
    title.Text = task.Title;
    AddLabeledControl("Notes", notes, 18, 112, 444, 78);
    notes.Multiline = true;
    notes.AcceptsReturn = true;
    notes.ScrollBars = ScrollBars.Vertical;
    notes.Text = task.Notes;

    var scheduleHeading = LabelFor("Schedule", 18, 196, 440, 22);
    scheduleHeading.Font = new Font("Segoe UI Semibold", 10, FontStyle.Bold);
    ConfigureDate(scheduled, task.ScheduledDate, 18, 242, 214);
    var scheduledLabel = LabelFor("Scheduled day", 18, 222, 214, 20);
    Controls.Add(scheduledLabel);
    Controls.Add(scheduled);
    ConfigureDate(deadline, task.DeadlineDate, 248, 242, 214);
    var deadlineLabel = LabelFor("Deadline", 248, 222, 214, 20);
    Controls.Add(deadlineLabel);
    Controls.Add(deadline);

    var organizationHeading = LabelFor("Organization", 18, 286, 440, 22);
    organizationHeading.Font = new Font("Segoe UI Semibold", 10, FontStyle.Bold);
    ConfigureDropDown(category, 18, 332, 214);
    category.Items.Add(new Choice("None / Inbox", ""));
    foreach (var item in repository.LoadCategories()) {
      category.Items.Add(new Choice(item.Name, item.Id));
    }
    SelectValue(category, task.CategoryId ?? "");
    category.SelectedIndexChanged += (_, _) => PopulateProjects(null);
    var categoryLabel = LabelFor("Category", 18, 312, 214, 20);
    Controls.Add(categoryLabel);
    Controls.Add(category);

    ConfigureDropDown(project, 248, 332, 214);
    var projectLabel = LabelFor("Project", 248, 312, 214, 20);
    Controls.Add(projectLabel);
    Controls.Add(project);
    PopulateProjects(task.ProjectId);

    var optionalHeading = LabelFor("Status and priority", 18, 376, 440, 22);
    optionalHeading.Font = new Font("Segoe UI Semibold", 10, FontStyle.Bold);
    ConfigureDropDown(status, 18, 422, 214);
    status.Items.AddRange([
      new Choice("Not started", "notStarted"),
      new Choice("In progress", "inProgress"),
      new Choice("Waiting", "waiting"),
      new Choice("On hold", "onHold"),
      new Choice("Completed", "completed"),
      new Choice("Cancelled", "cancelled"),
    ]);
    SelectValue(status, task.Status);
    var statusLabel = LabelFor("Status", 18, 402, 214, 20);
    Controls.Add(statusLabel);
    Controls.Add(status);

    ConfigureDropDown(priority, 248, 422, 214);
    priority.Items.AddRange([
      new Choice("None", "0"), new Choice("Low", "1"),
      new Choice("Medium", "2"), new Choice("High", "3"),
    ]);
    SelectValue(priority, task.Priority.ToString(CultureInfo.InvariantCulture));
    var priorityLabel = LabelFor("Priority", 248, 402, 214, 20);
    Controls.Add(priorityLabel);
    Controls.Add(priority);

    feedback.Location = new Point(18, 456);
    feedback.Size = new Size(444, 35);
    feedback.ForeColor = palette == WidgetPalette.Dark
      ? Color.FromArgb(255, 154, 154) : Color.FromArgb(165, 35, 35);

    var full = new Button {
      Text = "Open full details",
      Location = new Point(18, 498), Size = new Size(145, 38),
      FlatStyle = FlatStyle.Flat, ForeColor = palette.Foreground,
    };
    full.Click += (_, _) => {
      OpenFullDetails = true;
      DialogResult = DialogResult.Cancel;
      Close();
    };
    var cancel = new Button {
      Text = "Cancel", DialogResult = DialogResult.Cancel,
      Location = new Point(262, 498), Size = new Size(92, 38),
      FlatStyle = FlatStyle.Flat, ForeColor = palette.Foreground,
    };
    var save = new Button {
      Text = "Save", Location = new Point(362, 498), Size = new Size(100, 38),
      FlatStyle = FlatStyle.Flat, BackColor = palette.Accent,
      ForeColor = palette == WidgetPalette.Dark ? palette.Background : Color.White,
    };
    save.Click += (_, _) => SaveTask();
    CancelButton = cancel;
    AcceptButton = save;
    title.AccessibleName = "Task title";
    notes.AccessibleName = "Task notes";
    status.AccessibleName = "Task status";
    priority.AccessibleName = "Task priority";
    category.AccessibleName = "Task category";
    project.AccessibleName = "Task project";
    scheduled.AccessibleName = "Scheduled day";
    deadline.AccessibleName = "Deadline";
    Controls.AddRange([heading, scheduleHeading, organizationHeading,
      optionalHeading, feedback, full, cancel, save]);
    Shown += (_, _) => {
      var dark = palette == WidgetPalette.Dark ? 1 : 0;
      DwmSetWindowAttribute(Handle, 20, ref dark, sizeof(int));
      var caption = ColorRef(palette.Background);
      var captionText = ColorRef(palette.Foreground);
      DwmSetWindowAttribute(Handle, 35, ref caption, sizeof(int));
      DwmSetWindowAttribute(Handle, 36, ref captionText, sizeof(int));
      title.Focus();
      title.SelectAll();
    };
    foreach (Control input in new Control[] { title, notes, status, priority,
        category, project, scheduled, deadline }) {
      input.BackColor = palette.Panel;
      input.ForeColor = palette.Foreground;
      if (input is TextBox box) {
        box.BorderStyle = BorderStyle.FixedSingle;
      } else if (input is DateTimePicker picker) {
        picker.CalendarMonthBackground = palette.Panel;
        picker.CalendarForeColor = palette.Foreground;
        picker.CalendarTitleBackColor = palette.Background;
        picker.CalendarTitleForeColor = palette.Foreground;
      }
    }
    Resize += (_, _) => {
      var fullWidth = Math.Max(300, ClientSize.Width - 36);
      var column = Math.Max(135, (fullWidth - 16) / 2);
      var secondX = 18 + column + 16;
      heading.Width = scheduleHeading.Width = organizationHeading.Width =
        optionalHeading.Width = fullWidth;
      title.Width = notes.Width = feedback.Width = fullWidth;
      foreach (var input in new Control[] { status, category, scheduled })
        input.Width = column;
      foreach (var input in new Control[] { priority, project, deadline }) {
        input.Left = secondX;
        input.Width = column;
      }
      foreach (var label in new Control[] { statusLabel, categoryLabel, scheduledLabel })
        label.Width = column;
      foreach (var label in new Control[] { priorityLabel, projectLabel, deadlineLabel }) {
        label.Left = secondX;
        label.Width = column;
      }
      var bottom = ClientSize.Height - 56;
      full.Top = cancel.Top = save.Top = bottom;
      save.Left = ClientSize.Width - 118;
      cancel.Left = save.Left - 100;
    };
  }

  private void SaveTask() {
    try {
      var selectedStatus = (Choice)status.SelectedItem!;
      var selectedPriority = (Choice)priority.SelectedItem!;
      var update = new WidgetTaskUpdate(
        title.Text, notes.Text, selectedStatus.Value,
        int.Parse(selectedPriority.Value, CultureInfo.InvariantCulture),
        SelectedValue(category), SelectedValue(project), DateValue(scheduled),
        DateValue(deadline), original.UpdatedAt);
      try {
        repository.UpdateTask(original.Id, update);
      } catch (DependencyReviewRequiredException conflict) {
        var names = String.Join(", ", conflict.Conflicts.Select(item => item.Title));
        var answer = MessageBox.Show(this,
          $"This day is before unfinished prerequisite work: {names}. Save anyway?",
          "Plan before prerequisites?", MessageBoxButtons.YesNo,
          MessageBoxIcon.Warning);
        if (answer != DialogResult.Yes) return;
        repository.UpdateTask(original.Id, update with {
          ReviewedPrerequisiteIds = conflict.Conflicts.Select(item => item.Id).ToArray(),
        });
      }
      DialogResult = DialogResult.OK;
      Close();
    } catch (Exception error) {
      feedback.Text = error.Message;
    }
  }

  private static int ColorRef(Color color) =>
    color.R | (color.G << 8) | (color.B << 16);

  [DllImport("dwmapi.dll")]
  private static extern int DwmSetWindowAttribute(
    IntPtr window, int attribute, ref int value, int size);

  private void PopulateProjects(string? selected) {
    var categoryId = SelectedValue(category);
    project.Items.Clear();
    project.Items.Add(new Choice("None", ""));
    foreach (var item in projects.Where(item => item.ParentId == categoryId)) {
      project.Items.Add(new Choice(item.Name, item.Id));
    }
    SelectValue(project, selected ?? "");
    project.Enabled = categoryId != null;
  }

  private void AddLabeledControl(
      string label, Control control, int x, int y, int width, int height) {
    Controls.Add(LabelFor(label, x, y - 19, width, 20));
    control.Location = new Point(x, y);
    control.Size = new Size(width, height);
    Controls.Add(control);
  }

  private static Label LabelFor(string text, int x, int y, int width, int height) =>
    new() { Text = text, Location = new Point(x, y), Size = new Size(width, height) };

  private static void ConfigureDropDown(
      ComboBox control, int x, int y, int width) {
    control.DropDownStyle = ComboBoxStyle.DropDownList;
    control.Location = new Point(x, y);
    control.Size = new Size(width, 31);
  }

  private static void ConfigureDate(
      DateTimePicker control, string? value, int x, int y, int width) {
    control.Format = DateTimePickerFormat.Short;
    control.ShowCheckBox = true;
    control.Location = new Point(x, y);
    control.Size = new Size(width, 31);
    control.Checked = DateTime.TryParseExact(value, "yyyy-MM-dd",
      CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed);
    if (control.Checked) control.Value = parsed;
  }

  private static void SelectValue(ComboBox box, string value) {
    for (var index = 0; index < box.Items.Count; index++) {
      if (box.Items[index] is Choice choice && choice.Value == value) {
        box.SelectedIndex = index;
        return;
      }
    }
    if (box.Items.Count > 0) box.SelectedIndex = 0;
  }

  private static string? SelectedValue(ComboBox box) =>
    box.SelectedItem is Choice choice && choice.Value.Length > 0
      ? choice.Value : null;

  private static string? DateValue(DateTimePicker picker) => picker.Checked
    ? picker.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : null;

  private sealed record Choice(string Label, string Value) {
    public override string ToString() => Label;
  }
}
