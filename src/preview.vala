/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class Preview : Gtk.Widget {
    static construct {
        set_css_name ("preview");
    }

    private Gtk.AspectFrame? parent_frame = null;

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

    private Game? _game = null;
    public Game? game
    {
        get { return _game; }
        set
        {
            if (_game != null)
                SignalHandler.disconnect_matched (_game, SignalMatchType.DATA, 0, 0, null, null, this);
            _game = value;
            _game.shape_added.connect (shape_added_cb);
            update_block ();
        }
    }

    private bool _enabled = true;
    public bool enabled
    {
        get { return _enabled; }
        set { _enabled = value; update_block (); }
    }

    public Preview (Gtk.AspectFrame? parent)
    {
        parent_frame = parent;

        hexpand = true;
        vexpand = true;
    }

    private void shape_added_cb ()
    {
        update_block ();
    }

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

    protected override void dispose () {
        clear ();
    }

    public void clear () {
        foreach (var widget in block_widgets)
        {
            widget.destroy ();
        }

        block_widgets.remove_range (0, block_widgets.length);
    }

    private void update_block ()
    {
        if (block_widgets.length != 0) {
            clear ();
        }

        if (game == null || game.next_shape == null || !enabled)
        {
            // If the game is set up for preview but no preview is available, still show preview field
            set_visible (enabled);
            return;
        }

        set_visible (true);


        var min_width = 4, max_width = 0, min_height = 4, max_height = 0;
        foreach (var b in game.next_shape.blocks) {
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
        if (parent_frame != null)
        {
            parent_frame.set_visible (visible);
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
