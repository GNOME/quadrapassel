/* adaptive-card.vala
 *
 * Copyright 2026 Will Warner
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[GtkTemplate (ui = "/org/gnome/Quadrapassel/adaptive-card.ui")]
public class AdaptiveCard : Adw.Bin {
    [GtkChild]
    public unowned Gtk.Box box;
    [GtkChild]
    public unowned Gtk.Label info_type;
    [GtkChild]
    public unowned Gtk.Label info;

    public Gtk.Orientation orientation {
        set
        {
            box.orientation = value;

            if (value == Gtk.Orientation.HORIZONTAL)
            {
                this.vexpand = false;
                this.info.hexpand = true;
                this.info.margin_bottom = 0;
            }
            else
            {
                this.vexpand = true;
                this.info.hexpand = false;
                if (_compact == false)
                    this.info.margin_bottom = 2;
            }
        }
    }

    private bool _compact = false;

    public bool compact {
        set
        {
            _compact = value;

            if (value == true)
            {
                this.vexpand = false;
                this.info.margin_top = 2;
                this.info.hexpand = true;
                this.info.vexpand = false;
                this.info.margin_bottom = 0;
                this.info.halign = Gtk.Align.START;
                this.info_type.halign = Gtk.Align.START;
            }
            else
            {
                this.vexpand = true;
                this.info.margin_top = 0;
                this.info.hexpand = false;
                this.info.vexpand = true;
                this.info.margin_bottom = 2;
                this.info.halign = Gtk.Align.CENTER;
                this.info_type.halign = Gtk.Align.CENTER;
            }
        }
    }

    public AdaptiveCard (string info_type, string info)
    {
        this.info_type.label = info_type;
        this.info.label = info;
    }

    public override bool focus (Gtk.DirectionType direction)
    {
        if (this.is_focus ())
            return false;

        this.grab_focus ();
        return true;
    }
}
