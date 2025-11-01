/*
 * Copyright (C) 2025 Will Warner
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

[GtkTemplate (ui = "/org/gnome/Quadrapassel/more-info-button.ui")]
public class MoreInfoButton : Adw.Bin {
    [GtkChild]
    private unowned Gtk.Widget button;
    [GtkChild]
    private unowned Gtk.Label info_label;
    [GtkChild]
    private unowned Adw.Bin extra_widget_bin;

    private string _text = "";

    public string text {
        get { return _text; }
        set
        {
            if (value == null)
                _text = "";
            else
                _text = value;

            info_label.label = _text;
        }
    }

    public Gtk.Widget extra_child {
        get { return extra_widget_bin.get_child (); }
        set
        {
            if (value == null)
                extra_widget_bin.visible = false;
            else
                extra_widget_bin.visible = true;

            extra_widget_bin.set_child (value);
        }
    }

    construct {
        button.notify["active"].connect (() => {
            if (((Gtk.MenuButton) button).active)
                this.announce (_text, Gtk.AccessibleAnnouncementPriority.MEDIUM);
        });
    }

    public MoreInfoButton () {}
}
