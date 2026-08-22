/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2026 Will Warner
 *
 * This file is part of libgnome-games-support.
 *
 * libgnome-games-support is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * libgnome-games-support is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with libgnome-games-support.  If not, see <http://www.gnu.org/licenses/>.
 */

private class ThemeThumbnail : Gtk.Widget
{
    Gtk.Image image = new Gtk.Image.from_icon_name ("object-select-symbolic");
    Gtk.Widget child;

    class construct
    {
        set_css_name ("thumbnail");
    }

    public ThemeThumbnail (Gtk.Widget child)
    {
        this.child = child;
        this.child.set_parent (this);

        this.image.pixel_size = 14;
        this.image.halign = Gtk.Align.END;
        this.image.valign = Gtk.Align.END;
        this.image.visible = false;
        this.image.set_parent (this);
        this.layout_manager = new Gtk.BinLayout ();
    }

    public void set_selected (bool selected)
    {
        this.image.visible = selected;
        if (selected)
            this.add_css_class ("selected");
        else
            this.remove_css_class ("selected");
    }

    public override void measure (Gtk.Orientation orientation,
                                  int for_size,
                                  out int minimum,
                                  out int natural,
                                  out int minimum_baseline,
                                  out int natural_baseline)
    {
        child.measure (orientation, for_size, out minimum, out natural, out minimum_baseline, out natural_baseline);
    }

    public override void dispose ()
    {
        this.image.unparent ();
        this.child.unparent ();

        base.dispose ();
    }
}

namespace Games {

private const string CSS_STYLE = """
thumbnail {
  border-radius: 8px;
}

thumbnail.selected image {
  border-radius: 9999px;
  background-color: @theme_selected_bg_color;
  color: @theme_selected_fg_color;
  padding: 2px;
}

/* shadows taken from gnome-text-editor, licensed under GPLv3, see COPYING */
thumbnail {
  box-shadow: 0 0 0 1px alpha(black, 0.03),
              0 1px 3px 1px alpha(black, .07),
              0 2px 6px 2px alpha(black, .03);
}
@media (prefers-contrast: more) {
  thumbnail {
    box-shadow: 0 0 0 1px @borders,
                0 1px 3px 1px alpha(black, .07),
                0 2px 6px 2px alpha(black, .03);
  }
}
""";

public class AppearanceGroup : Adw.PreferencesGroup
{
    private string[] theme_names;
    Adw.Bin preview_bin = new Adw.Bin ();
    Gtk.FlowBox thumbnail_box = new Gtk.FlowBox ();
    ThemeThumbnail selected;

    class construct
    {
        /* Styling */
        var display = Gdk.Display.get_default ();
        if (display != null)
        {
            var provider = new Gtk.CssProvider ();
            provider.load_from_string (CSS_STYLE);
            Workaround.gtk_style_context_add_provider_for_display (
                display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
         }
    }

    /**
     * Emitted when the user selects a new theme.
     *
     * `name` is the name of the selected theme.
     *
     * `old_preview` is the main preview widget for the previously selected theme
     *
     * The return value will be used as the main preview widget for the selected theme.
     *
     */
    public signal Gtk.Widget change_theme (string name, Gtk.Widget old_preview);

    private void thumbnail_activated (Gtk.FlowBox flow_box, Gtk.FlowBoxChild child)
    {
        selected.set_selected (false);
        ((Gtk.Accessible) selected.parent).update_state (Gtk.AccessibleState.CHECKED, false, -1);

        var new_selected = (ThemeThumbnail) child.child;
        new_selected.set_selected (true);
        ((Gtk.Accessible) child).update_state (Gtk.AccessibleState.CHECKED, true, -1);

        preview_bin.child = change_theme (theme_names[child.get_index ()], preview_bin.child);

        selected = new_selected;
    }

    /**
     * Creates a new AppearanceGroup
     *
     */
    public AppearanceGroup ()
    {
        this.title = _("Appearance");

        this.preview_bin.margin_bottom = 24;

        this.thumbnail_box.child_activated.connect (thumbnail_activated);
        this.thumbnail_box.halign = Gtk.Align.CENTER;
        this.thumbnail_box.selection_mode = Gtk.SelectionMode.NONE;
        this.thumbnail_box.column_spacing = 12;
        this.thumbnail_box.row_spacing = 12;

        var builder = new Gtk.Builder ();
        this.add_child (builder, preview_bin, null);
        this.add_child (builder, thumbnail_box, null);
    }

    /**
     * Adds a new theme for the user to select
     * All themes in the game should be added through this.
     *
     * `name` is the name of the theme.
     *
     * `thumbnail` is the small preview of the theme that can be selected.
     *
     */
    public void add_theme (string name, Gtk.Widget thumbnail)
    {
        this.theme_names += name;

        var box_child = new Gtk.FlowBoxChild ();

        box_child.accessible_role = Gtk.AccessibleRole.TOGGLE_BUTTON;
        ((Gtk.Accessible) box_child).update_property (Gtk.AccessibleProperty.LABEL, name, -1);
        ((Gtk.Accessible) box_child).update_state (Gtk.AccessibleState.CHECKED, false, -1);

        box_child.set_child (new ThemeThumbnail (thumbnail));
        this.thumbnail_box.append (box_child);

        this.thumbnail_box.max_children_per_line = theme_names.length;
    }

    /**
     * Sets the main preview widget
     * This should be called once, after all the themes are added.
     *
     * `active_theme` is the name of the active theme.
     *
     * `preview` is the main preview widget for the active theme, it is switched with change_theme.
     *
     */
    public void set_preview (string active_theme, Gtk.Widget preview)
    {
        this.preview_bin.child = preview;

        for (int i = 0; i < theme_names.length; i++)
        {
            if (theme_names[i] == active_theme)
            {
                var box_child = thumbnail_box.get_child_at_index (i);
                ((Gtk.Accessible) box_child).update_state (Gtk.AccessibleState.CHECKED, true, -1);

                var theme_thumbnail = (ThemeThumbnail) box_child.child;
                theme_thumbnail.set_selected (true);
                this.selected = theme_thumbnail;
            }
        }
    }
}

} /* namespace Games */
