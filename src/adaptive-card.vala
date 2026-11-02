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
public class AdaptiveCard : Gtk.Box {
    [GtkChild]
    public unowned Gtk.Label info_type;
    [GtkChild]
    public unowned Gtk.Label info;

    public string info_type_string {
        set
        {
            info_type.label = value;
        }
    }

    public string info_string {
        set
        {
            info.label = value;
        }
    }

    private bool _compact = false;

    public bool compact {
        set
        {
            _compact = value;

            if (value == true)
                this.info.set_css_classes ({ "title-4" });
            else
                this.info.set_css_classes ({ "title-2" });
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
