using System.Drawing;
using System.Windows.Forms;

internal static class WidgetMenuStyle {
  internal static void Apply(ContextMenuStrip menu, WidgetPalette palette) {
    menu.RenderMode = ToolStripRenderMode.ManagerRenderMode;
    menu.Renderer = new ToolStripProfessionalRenderer(new PaletteColors(palette));
    menu.BackColor = palette.Panel;
    menu.ForeColor = palette.Foreground;
    menu.Font = new Font("Segoe UI", 9.5f);
    menu.ShowImageMargin = false;
    menu.Padding = new Padding(4);
    foreach (ToolStripItem item in menu.Items) ApplyItem(item, palette);
  }

  private static void ApplyItem(ToolStripItem item, WidgetPalette palette) {
    item.BackColor = palette.Panel;
    item.ForeColor = palette.Foreground;
    if (item is ToolStripMenuItem menuItem) {
      menuItem.Padding = new Padding(8, 5, 8, 5);
      menuItem.DropDown.BackColor = palette.Panel;
      menuItem.DropDown.ForeColor = palette.Foreground;
      foreach (ToolStripItem child in menuItem.DropDownItems) {
        ApplyItem(child, palette);
      }
    }
  }

  private sealed class PaletteColors(WidgetPalette palette) : ProfessionalColorTable {
    public override Color ToolStripDropDownBackground => palette.Panel;
    public override Color MenuBorder => palette.Border;
    public override Color MenuItemBorder => palette.AccentBorder;
    public override Color MenuItemSelected => Color.FromArgb(40, palette.Accent);
    public override Color MenuItemSelectedGradientBegin => MenuItemSelected;
    public override Color MenuItemSelectedGradientEnd => MenuItemSelected;
    public override Color MenuItemPressedGradientBegin => MenuItemSelected;
    public override Color MenuItemPressedGradientEnd => MenuItemSelected;
    public override Color CheckBackground => Color.FromArgb(42, palette.Accent);
    public override Color CheckSelectedBackground => Color.FromArgb(66, palette.Accent);
    public override Color CheckPressedBackground => Color.FromArgb(80, palette.Accent);
    public override Color ImageMarginGradientBegin => palette.Panel;
    public override Color ImageMarginGradientMiddle => palette.Panel;
    public override Color ImageMarginGradientEnd => palette.Panel;
    public override Color SeparatorDark => palette.Border;
    public override Color SeparatorLight => palette.Border;
  }
}
