/* preview.vala
 * 
 * Copyright 2010-2013 Robert Ancell
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

public class Preview : Gtk.Widget {
    static construct {
        set_css_name ("preview");
    }

    private string _theme;
    public string theme
    {
        get { return _theme; }
        set
        {
            foreach (var block in block_widgets) {
                block.theme = value;
            }

            _theme = value;
        }
    }

    private Array<BlockWidget> block_widgets = new Array<BlockWidget> ();
    private int piece_width;
    private int piece_height;

    private int cell_size
    {
        get { return (get_width () + get_height ()) / 2 / 5; }
    }

    private bool _enabled = true;
    public bool enabled
    {
        get { return _enabled; }
        set { _enabled = value; update_block (null); }
    }

    public Preview () {}

    protected override void snapshot (Gtk.Snapshot snapshot) {
        foreach (var widget in block_widgets) {
            snapshot_child (widget, snapshot);
        }
    }

    protected override void size_allocate (int width, int height, int baseline) {
        var block_width = width / 5;
        var block_height = height / 5;

        foreach (var widget in block_widgets) {
            Graphene.Point pos = Graphene.Point () {
                x = (5 - piece_width) * block_width / 2 + widget.block.x * block_width,
                y = (5 - piece_height) * block_height / 2 + widget.block.y * block_height,
            };

            var transform = new Gsk.Transform ();
            transform = transform.translate (pos);
            //widget.measure (Gtk.Orientation.HORIZONTAL, 10, null, null, null, null);
            widget.allocate (block_width, block_height, -1, transform);
        }
    }

    protected override void measure (Gtk.Orientation orientation,
                                     int for_size,
                                     out int minimum,
                                     out int natural,
                                     out int minimum_baseline,
                                     out int natural_baseline)
    {

        minimum = 50;
        natural = 120;
        minimum_baseline = natural_baseline = -1;
    }

    protected override void dispose () {
        clear ();
        base.dispose ();
    }

    public void clear () {
        foreach (var widget in block_widgets)
        {
            widget.unparent ();
            widget.destroy ();
        }

        block_widgets.remove_range (0, block_widgets.length);
    }

    public void update_block (Shape? shape)
    {
        if (block_widgets.length != 0) {
            clear ();
        }

        if (!enabled || shape == null)
        {
            set_visible (enabled);
            return;
        }

        set_visible (true);

        var min_width = 4, max_width = 0, min_height = 4, max_height = 0;
        foreach (var b in shape.blocks) {
            min_width = int.min (b.x, min_width);
            max_width = int.max (b.x + 1, max_width);
            min_height = int.min (b.y, min_height);
            max_height = int.max (b.y + 1, max_height);

            var widget = new BlockWidget (b, theme);
            widget.color = b.color;
            widget.theme = theme;
            widget.set_parent (this);
            this.block_widgets.append_val (widget);
        }

        piece_width = min_width + max_width;
        piece_height = min_height + max_height;

        queue_allocate ();
    }

    public new void set_visible (bool visible)
    {
        base.set_visible (visible);
        if (this.parent != null)
        {
            this.parent.set_visible (visible);
        }
    }

    public void set_hidden (bool hide)
    {
        foreach (var widget in block_widgets)
        {
            widget.set_visible (!hide);
        }
    }
}
