/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class Preview : GtkClutter.Embed
{
    /* Textures used to draw blocks */
    private BlockTexture[] block_textures;

    /* Clutter representation of a piece */
    private Clutter.Actor? piece = null;

    private Gtk.Frame? parent_frame = null;

    public string theme
    {
        set
        {
            foreach (var texture in block_textures)
                texture.theme = value;
            update_block ();
        }
    }

    private int cell_size
    {
        get { return (get_allocated_width () + get_allocated_height ()) / 2 / 5; }
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

    public Preview (Gtk.Frame? parent)
    {
        size_allocate.connect (size_allocate_cb);

        parent_frame = parent;

        /* FIXME: We should scale with the rest of the UI, but that requires
         * changes to the widget layout - i.e. wrap the preview in an
         * fixed-aspect box. */
        set_size_request (120, 120);
        var stage = (Clutter.Stage) get_stage ();

        Clutter.Color stage_color = { 0x0, 0x0, 0x0, 0xff };
        stage.set_background_color (stage_color);

        block_textures = new BlockTexture[NCOLORS];
        for (var i = 0; i < block_textures.length; i++)
        {
            block_textures[i] = new BlockTexture (i);
            // FIXME: Have to set a size to avoid an assertion in Clutter
            block_textures[i].set_surface_size (1, 1);
            block_textures[i].hide ();
            stage.add_child (block_textures[i]);
        }
    }

    private void shape_added_cb ()
    {
        update_block ();
    }

    private void update_block ()
    {
        if (piece != null)
            piece.destroy ();

        if (game == null || game.next_shape == null || !enabled)
        {
            // If the game is set up for preview but no preview is available, still show preview field
            set_visible (enabled);
            return;
        }

        set_visible (true);

        piece = new Clutter.Actor ();
        var stage = (Clutter.Stage) get_stage ();
        stage.add_child (piece);

        var min_width = 4, max_width = 0, min_height = 4, max_height = 0;
        foreach (var b in game.next_shape.blocks)
        {
            min_width = int.min (b.x, min_width);
            max_width = int.max (b.x + 1, max_width);
            min_height = int.min (b.y, min_height);
            max_height = int.max (b.y + 1, max_height);

            var a = new Clutter.Clone (block_textures[b.color]);
            a.set_size (cell_size, cell_size);
            a.set_position (b.x * cell_size, b.y * cell_size);
            piece.add_child (a);
        }

        piece.set_pivot_point (0.5f, 0.5f);
        piece.set_position ((get_allocated_width () - (min_width + max_width) * cell_size) / 2, (get_allocated_height () - (min_height + max_height) * cell_size) / 2);
        piece.set_scale (0.6, 0.6);

        piece.save_easing_state ();
        piece.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_SINE);
        piece.set_easing_duration (180);
        piece.set_scale (1.0, 1.0);
        piece.restore_easing_state ();
    }

    public new void set_visible (bool visible)
    {
        base.set_visible (visible);
        if (parent_frame != null)
        {
            parent_frame.set_visible (visible);
        }
    }

    private void size_allocate_cb (Gtk.Allocation allocation)
    {
        foreach (var texture in block_textures)
            texture.set_size (cell_size, cell_size);
        update_block ();
    }
}
