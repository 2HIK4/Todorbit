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
    // Check glyphs have their own column; hiding the image margin used to hide
    // the native checked state as well.
    menu.ShowCheckMargin = true;
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
      if (menuItem.DropDown is ToolStripDropDownMenu childMenu) {
        childMenu.ShowImageMargin = false;
        childMenu.ShowCheckMargin = true;
      }
      foreach (ToolStripItem child in menuItem.DropDownItems) {
        ApplyItem(child, palette);
      }
    }
  }

  private sealed class PaletteColors(WidgetPalette palette) : ProfessionalColorTable {
    public override Color ToolStripDropDownBackground => palette.Panel;
    public override Color MenuBorder => palette.Border;
    public override Color MenuItemBorder => palette.AccentBorder;
    public override Color MenuItemSelected =>
      WidgetEditorStyle.Blend(palette.Panel, palette.Accent, 0.15f);
    public override Color MenuItemSelectedGradientBegin => MenuItemSelected;
    public override Color MenuItemSelectedGradientEnd => MenuItemSelected;
    public override Color MenuItemPressedGradientBegin => MenuItemSelected;
    public override Color MenuItemPressedGradientEnd => MenuItemSelected;
    public override Color CheckBackground =>
      WidgetEditorStyle.Blend(palette.Panel, palette.Accent, 0.18f);
    public override Color CheckSelectedBackground =>
      WidgetEditorStyle.Blend(palette.Panel, palette.Accent, 0.26f);
    public override Color CheckPressedBackground =>
      WidgetEditorStyle.Blend(palette.Panel, palette.Accent, 0.32f);
    public override Color ImageMarginGradientBegin => palette.Panel;
    public override Color ImageMarginGradientMiddle => palette.Panel;
    public override Color ImageMarginGradientEnd => palette.Panel;
    public override Color SeparatorDark => palette.Border;
    public override Color SeparatorLight => palette.Border;
  }
}
