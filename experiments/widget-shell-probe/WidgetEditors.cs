using System.Globalization;

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
    Text = "Quick Add - Life Manager";
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
    Text = "Edit task - Life Manager";
    FormBorderStyle = FormBorderStyle.FixedDialog;
    StartPosition = FormStartPosition.Manual;
    ClientSize = new Size(480, 570);
    MaximizeBox = false;
    MinimizeBox = false;
    ShowInTaskbar = true;
    BackColor = palette.Background;
    ForeColor = palette.Foreground;
    Font = new Font("Segoe UI", 9.5f);

    var heading = LabelFor("Task details", 18, 15, 440, 28);
    heading.Font = new Font("Segoe UI Semibold", 15, FontStyle.Bold);
    AddLabeledControl("Title *", title, 18, 58, 444, 31);
    title.Text = task.Title;
    AddLabeledControl("Notes", notes, 18, 112, 444, 78);
    notes.Multiline = true;
    notes.ScrollBars = ScrollBars.Vertical;
    notes.Text = task.Notes;

    ConfigureDropDown(status, 18, 214, 214);
    status.Items.AddRange([
      new Choice("Not started", "notStarted"),
      new Choice("In progress", "inProgress"),
      new Choice("Waiting", "waiting"),
      new Choice("On hold", "onHold"),
      new Choice("Completed", "completed"),
      new Choice("Cancelled", "cancelled"),
    ]);
    SelectValue(status, task.Status);
    Controls.Add(LabelFor("Status", 18, 195, 214, 20));
    Controls.Add(status);

    ConfigureDropDown(priority, 248, 214, 214);
    priority.Items.AddRange([
      new Choice("None", "0"), new Choice("Low", "1"),
      new Choice("Medium", "2"), new Choice("High", "3"),
    ]);
    SelectValue(priority, task.Priority.ToString(CultureInfo.InvariantCulture));
    Controls.Add(LabelFor("Priority", 248, 195, 214, 20));
    Controls.Add(priority);

    ConfigureDropDown(category, 18, 272, 214);
    category.Items.Add(new Choice("None / Inbox", ""));
    foreach (var item in repository.LoadCategories()) {
      category.Items.Add(new Choice(item.Name, item.Id));
    }
    SelectValue(category, task.CategoryId ?? "");
    category.SelectedIndexChanged += (_, _) => PopulateProjects(null);
    Controls.Add(LabelFor("Category", 18, 253, 214, 20));
    Controls.Add(category);

    ConfigureDropDown(project, 248, 272, 214);
    Controls.Add(LabelFor("Project", 248, 253, 214, 20));
    Controls.Add(project);
    PopulateProjects(task.ProjectId);

    ConfigureDate(scheduled, task.ScheduledDate, 18, 330, 214);
    Controls.Add(LabelFor("Scheduled day", 18, 311, 214, 20));
    Controls.Add(scheduled);
    ConfigureDate(deadline, task.DeadlineDate, 248, 330, 214);
    Controls.Add(LabelFor("Deadline", 248, 311, 214, 20));
    Controls.Add(deadline);

    feedback.Location = new Point(18, 374);
    feedback.Size = new Size(444, 43);
    feedback.ForeColor = Color.FromArgb(205, 72, 72);

    var full = new Button {
      Text = "Open full details",
      Location = new Point(18, 497), Size = new Size(145, 38),
      FlatStyle = FlatStyle.Flat, ForeColor = palette.Foreground,
    };
    full.Click += (_, _) => {
      OpenFullDetails = true;
      DialogResult = DialogResult.Cancel;
      Close();
    };
    var cancel = new Button {
      Text = "Cancel", DialogResult = DialogResult.Cancel,
      Location = new Point(262, 497), Size = new Size(92, 38),
      FlatStyle = FlatStyle.Flat, ForeColor = palette.Foreground,
    };
    var save = new Button {
      Text = "Save", Location = new Point(362, 497), Size = new Size(100, 38),
      FlatStyle = FlatStyle.Flat, BackColor = palette.Accent, ForeColor = Color.White,
    };
    save.Click += (_, _) => SaveTask();
    CancelButton = cancel;
    Controls.AddRange([heading, feedback, full, cancel, save]);
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
