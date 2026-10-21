using System.Globalization;

internal sealed class TaskEditorDialog : Form {
  private readonly LifeManagerWidgetRepository repository;
  private readonly WidgetTask original;
  private readonly WidgetPalette palette;
  private readonly IReadOnlyList<WidgetChoice> projects;
  private readonly WidgetEditorScrollPanel content;
  private readonly Panel footer = new();
  private readonly WidgetTextInput title;
  private readonly WidgetTextInput notes;
  private readonly WidgetChoiceBox category;
  private readonly WidgetChoiceBox project;
  private readonly WidgetChoiceBox status;
  private readonly WidgetChoiceBox priority;
  private readonly WidgetDateInput scheduled;
  private readonly WidgetDateInput deadline;
  private readonly Label heading;
  private readonly Label scheduleHeading;
  private readonly Label organizationHeading;
  private readonly Label statusHeading;
  private readonly Label titleLabel;
  private readonly Label notesLabel;
  private readonly Label scheduledLabel;
  private readonly Label deadlineLabel;
  private readonly Label categoryLabel;
  private readonly Label projectLabel;
  private readonly Label statusLabel;
  private readonly Label priorityLabel;
  private readonly Label feedback;
  private readonly Button full;
  private readonly Button cancel;
  private readonly Button save;
  internal bool OpenFullDetails { get; private set; }
  internal bool IsStacked =>
    content.ClientSize.Width - WidgetEditorStyle.Margin * 2 < 430;
  internal int ContentHeight => content.ContentHeight;

  internal TaskEditorDialog(LifeManagerWidgetRepository repository,
      WidgetTask task, WidgetPalette palette) {
    this.repository = repository;
    original = task;
    this.palette = palette;
    projects = repository.LoadProjects();
    content = new WidgetEditorScrollPanel(palette);
    Text = "Edit task - Todorbit";
    FormBorderStyle = FormBorderStyle.Sizable;
    StartPosition = FormStartPosition.Manual;
    ClientSize = new Size(550, 570);
    MinimumSize = new Size(360, 340);
    AutoScaleMode = AutoScaleMode.Dpi;
    MaximizeBox = false;
    MinimizeBox = false;
    ShowInTaskbar = true;
    BackColor = palette.Background;
    ForeColor = palette.Foreground;
    Font = new Font("Segoe UI", 9.5f);

    title = new WidgetTextInput(palette, "Task title") { Value = task.Title };
    notes = new WidgetTextInput(palette, "Task notes", true) { Value = task.Notes };
    scheduled = new WidgetDateInput(palette, "Scheduled day", task.ScheduledDate);
    deadline = new WidgetDateInput(palette, "Deadline", task.DeadlineDate);
    category = new WidgetChoiceBox(palette, "Task category");
    project = new WidgetChoiceBox(palette, "Task project");
    status = new WidgetChoiceBox(palette, "Task status");
    priority = new WidgetChoiceBox(palette, "Task priority");

    category.SetChoices(
      new[] { ("None / Inbox", "") }.Concat(repository.LoadCategories()
        .Select(item => (item.Name, item.Id))), task.CategoryId);
    category.ValueChanged += (_, _) => PopulateProjects(null);
    PopulateProjects(task.ProjectId);
    status.SetChoices([
      ("Not started", "notStarted"), ("In progress", "inProgress"),
      ("Waiting", "waiting"), ("On hold", "onHold"),
      ("Completed", "completed"), ("Cancelled", "cancelled"),
    ], task.Status);
    priority.SetChoices([
      ("None", "0"), ("Low", "1"), ("Medium", "2"), ("High", "3"),
    ], task.Priority.ToString(CultureInfo.InvariantCulture));

    heading = Heading("Task details", 15);
    scheduleHeading = Heading("Schedule");
    organizationHeading = Heading("Organization");
    statusHeading = Heading("Status and priority");
    titleLabel = FieldLabel("Title *");
    notesLabel = FieldLabel("Notes");
    scheduledLabel = FieldLabel("Scheduled day");
    deadlineLabel = FieldLabel("Deadline");
    categoryLabel = FieldLabel("Category");
    projectLabel = FieldLabel("Project");
    statusLabel = FieldLabel("Status");
    priorityLabel = FieldLabel("Priority");
    content.BackColor = palette.Background;
    content.Controls.AddRange([
      heading, titleLabel, title, notesLabel, notes,
      scheduleHeading, scheduledLabel, scheduled, deadlineLabel, deadline,
      organizationHeading, categoryLabel, category, projectLabel, project,
      statusHeading, statusLabel, status, priorityLabel, priority,
    ]);

    footer.Height = 64;
    footer.BackColor = palette.Background;
    feedback = new Label {
      ForeColor = WidgetEditorStyle.Error(palette),
      AutoEllipsis = true,
      TextAlign = ContentAlignment.MiddleLeft,
      Visible = false,
    };
    full = WidgetEditorStyle.Button("Open full details", palette);
    full.Click += (_, _) => {
      OpenFullDetails = true;
      DialogResult = DialogResult.Cancel;
      Close();
    };
    cancel = WidgetEditorStyle.Button("Cancel", palette);
    cancel.DialogResult = DialogResult.Cancel;
    save = WidgetEditorStyle.Button("Save", palette, true);
    save.Click += (_, _) => SaveTask();
    footer.Controls.AddRange([feedback, full, cancel, save]);
    Controls.Add(content);
    Controls.Add(footer);
    footer.Dock = DockStyle.Bottom;
    content.Dock = DockStyle.Fill;
    AcceptButton = save;
    CancelButton = cancel;
    content.Resize += (_, _) => LayoutContent();
    content.ScrollChanged += (_, _) => LayoutContent();
    MouseWheel += (_, e) => content.ScrollBy(-e.Delta / 120 * 58);
    foreach (Control child in content.Controls) {
      child.MouseWheel += (_, e) => content.ScrollBy(-e.Delta / 120 * 58);
    }
    foreach (Control field in new Control[] { title, notes, scheduled,
        deadline, category, project, status, priority }) {
      field.Enter += (_, _) => EnsureVisible(field);
    }
    footer.Resize += (_, _) => LayoutFooter();
    Shown += (_, _) => {
      var working = Screen.FromControl(this).WorkingArea;
      Height = Math.Min(Height, Math.Max(MinimumSize.Height, working.Height - 40));
      WidgetEditorStyle.ApplyCaption(this, palette);
      LayoutContent();
      LayoutFooter();
      title.FocusEditor(true);
    };
    LayoutContent();
    LayoutFooter();
  }

  private Label Heading(string value, float size = 10f) => new() {
    Text = value,
    ForeColor = palette.Foreground,
    Font = new Font("Segoe UI Semibold", size, FontStyle.Bold),
    AutoEllipsis = true,
  };

  private Label FieldLabel(string value) => new() {
    Text = value,
    ForeColor = palette.Muted,
    Font = new Font("Segoe UI", 9f),
    AutoEllipsis = true,
  };

  private void PopulateProjects(string? selected) {
    var categoryId = category.Value;
    project.SetChoices(
      new[] { ("None", "") }.Concat(projects
        .Where(item => item.ParentId == categoryId)
        .Select(item => (item.Name, item.Id))), selected);
    project.Enabled = categoryId != null;
  }

  private void LayoutContent() {
    if (content.IsDisposed || content.ClientSize.Width < 1) return;
    content.SuspendLayout();
    var left = WidgetEditorStyle.Margin;
    var width = Math.Max(200, content.ClientSize.Width - left * 2 -
      (content.Scrollable ? 12 : 0));
    var stacked = IsStacked;
    var columnWidth = stacked ? width : (width - WidgetEditorStyle.Gap) / 2;
    var right = left + columnWidth + WidgetEditorStyle.Gap;
    var y = 16;
    var scroll = content.ScrollOffset;
    heading.SetBounds(left, y - scroll, width, 32); y += 38;
    PlaceField(titleLabel, title, left, y - scroll, width, 36); y += 59;
    PlaceField(notesLabel, notes, left, y - scroll, width, 70); y += 93;
    scheduleHeading.SetBounds(left, y - scroll, width, 24); y += 29;
    PlaceField(scheduledLabel, scheduled, left, y - scroll, columnWidth, 36);
    if (stacked) {
      y += 61;
      PlaceField(deadlineLabel, deadline, left, y - scroll, width, 36);
    } else PlaceField(deadlineLabel, deadline, right, y - scroll, columnWidth, 36);
    y += 68;
    organizationHeading.SetBounds(left, y - scroll, width, 24); y += 29;
    PlaceField(categoryLabel, category, left, y - scroll, columnWidth, 36);
    if (stacked) {
      y += 61;
      PlaceField(projectLabel, project, left, y - scroll, width, 36);
    } else PlaceField(projectLabel, project, right, y - scroll, columnWidth, 36);
    y += 68;
    statusHeading.SetBounds(left, y - scroll, width, 24); y += 29;
    PlaceField(statusLabel, status, left, y - scroll, columnWidth, 36);
    if (stacked) {
      y += 61;
      PlaceField(priorityLabel, priority, left, y - scroll, width, 36);
    } else PlaceField(priorityLabel, priority, right, y - scroll, columnWidth, 36);
    y += 73;
    var previousScrollable = content.Scrollable;
    content.SetContentHeight(y);
    content.ResumeLayout();
    if (scroll != content.ScrollOffset || previousScrollable != content.Scrollable)
      LayoutContent();
  }

  private static void PlaceField(Label label, Control input,
      int x, int y, int width, int height) {
    label.SetBounds(x, y, width, 19);
    input.SetBounds(x, y + 20, width, height);
  }

  private void EnsureVisible(Control field) {
    var top = field.Top + content.ScrollOffset;
    if (field.Top < 8) content.ScrollTo(Math.Max(0, top - 24));
    else if (field.Bottom > content.ClientSize.Height - 8) {
      content.ScrollTo(top + field.Height - content.ClientSize.Height + 24);
    }
  }

  private void LayoutFooter() {
    var width = footer.ClientSize.Width;
    var narrow = width < 450;
    footer.Height = narrow ? 97 : 64;
    feedback.SetBounds(20, 0, width - 40, 20);
    if (narrow) {
      full.SetBounds(20, 21, Math.Max(145, width - 40), 31);
      cancel.SetBounds(width - 208, 56, 88, 34);
      save.SetBounds(width - 112, 56, 92, 34);
    } else {
      full.SetBounds(20, 23, 150, 34);
      cancel.SetBounds(width - 208, 23, 88, 34);
      save.SetBounds(width - 112, 23, 92, 34);
    }
    footer.Invalidate();
  }

  private void SaveTask() {
    try {
      var update = new WidgetTaskUpdate(
        title.Value, notes.Value, status.Value ?? "notStarted",
        int.Parse(priority.Value ?? "0", CultureInfo.InvariantCulture),
        category.Value, project.Value, scheduled.DateValue,
        deadline.DateValue, original.UpdatedAt);
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
      feedback.Visible = true;
    }
  }

}
