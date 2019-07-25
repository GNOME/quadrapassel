/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class GameView : GtkClutter.Embed
{
    /* Game being played */
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
            _game.shape_moved.connect (shape_moved_cb);
            _game.shape_dropped.connect (shape_dropped_cb);
            _game.shape_rotated.connect (shape_rotated_cb);
            _game.shape_landed.connect (shape_landed_cb);
            _game.pause_changed.connect (pause_changed_cb);
            _game.complete.connect (game_complete_cb);

            /* Remove any existing block */
            blocks.remove_all ();
            playing_field.remove_all_children ();
            shape_shadow = null;

            /* Add in the current blocks */
            if (game.shape != null)
                shape_added_cb ();
            for (var x = 0; x < _game.width; x++)
            {
                for (var y = 0; y < _game.height; y++)
                {
                    var block = _game.blocks[x, y];
                    if (block != null)
                    {
                        var actor = new BlockActor (block, block_textures[block.color]);
                        blocks.insert (block, actor);
                        actor.set_size (cell_size, cell_size);
                        actor.set_position (block.x * cell_size, block.y * cell_size);
                        playing_field.add (actor);
                    }
                }
            }

            set_size_request (_game.width * 190 / _game.height, 190);
            update_message ();
        }
    }

    /* Theme to use */
    public string theme
    {
        set
        {
            foreach (var texture in block_textures)
                texture.theme = value;
        }
    }

    private Clutter.Actor playing_field;

    /* The shape currently falling */
    private Clutter.Actor? shape = null;

    /* Shadow of falling piece */
    private Clutter.Clone? shape_shadow = null;

    private bool _show_shadow = false;
    public bool show_shadow
    {
        get { return _show_shadow; }
        set { _show_shadow = value; update_shadow (); }
    }

    /* Overlay to draw messages on */
    private TextOverlay text_overlay;

    /* Textures used to draw blocks */
    private BlockTexture[] block_textures;

    /* Blocks */
    private HashTable<Block, BlockActor> blocks;
    private HashTable<Block, BlockActor> shape_blocks;

    /* Number of lines destroyed (required for earthquake effect) */
    private int n_lines_destroyed;

    private int cell_size
    {
        get
        {
            if (game != null)
                return int.min (get_allocated_width () / game.width, get_allocated_height () / game.height);
            else
                return 0;
        }
    }

    public GameView ()
    {
        blocks = new HashTable<Block, BlockActor> (direct_hash, direct_equal);
        shape_blocks = new HashTable<Block, BlockActor> (direct_hash, direct_equal);

        size_allocate.connect (size_allocate_cb);

        var stage = (Clutter.Stage) get_stage ();
        Clutter.Color stage_color = { 0x10, 0x10, 0x10, 0xff };
        Clutter.Color field_color = { 0x0, 0x0, 0x0, 0xff };
        stage.set_background_color (stage_color);

        playing_field = new Clutter.Actor ();
        playing_field.set_background_color (field_color);
        stage.add_child (playing_field);

        text_overlay = new TextOverlay ();
        // FIXME: Have to set a size to avoid an assertion in Clutter
        text_overlay.set_surface_size (1, 1);
        stage.add (text_overlay);

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
        shape = new Clutter.Actor ();
        playing_field.add (shape);
        shape.set_position (game.shape.x * cell_size, game.shape.y * cell_size);
        update_shadow ();

        foreach (var block in game.shape.blocks)
        {
            var actor = new BlockActor (block, block_textures[block.color]);
            shape_blocks.insert (block, actor);
            shape.add (actor);
            actor.set_size (cell_size, cell_size);
            actor.set_position (block.x * cell_size, block.y * cell_size);
        }
    }

    private void shape_moved_cb ()
    {
        play_sound ("slide");
        shape.save_easing_state ();
        shape.set_easing_mode (Clutter.AnimationMode.EASE_IN_QUAD);
        shape.set_easing_duration (30);
        shape.set_x ((float) game.shape.x * cell_size);
        if (shape_shadow != null)
            shape_shadow.set_position (game.shape.x * cell_size, game.shadow_y * cell_size);
        shape.restore_easing_state ();
    }

    private void update_shadow ()
    {
        if (game != null && game.shape != null && show_shadow)
        {
            if (shape_shadow == null)
            {
                shape_shadow = new Clutter.Clone (shape);
                shape_shadow.set_opacity (32);
                playing_field.add (shape_shadow);
            }
            shape_shadow.set_position (game.shape.x * cell_size, game.shadow_y * cell_size);
        }
        else
        {
            if (shape_shadow != null)
                shape_shadow.destroy ();
            shape_shadow = null;
        }
    }

    private void shape_dropped_cb ()
    {
        shape.save_easing_state ();
        shape.set_easing_mode (Clutter.AnimationMode.EASE_IN_QUAD);
        shape.set_easing_duration (60);
        shape.set_y ((float) game.shape.y * cell_size);
        update_shadow ();
        shape.restore_easing_state ();
    }

    private void shape_rotated_cb ()
    {
        play_sound ("turn");
        foreach (var block in game.shape.blocks)
        {
            var actor = shape_blocks.lookup (block);
            actor.set_position (block.x * cell_size, block.y * cell_size);
        }
        update_shadow ();
    }

    private void shape_landed_cb (int[] lines, List<Block> line_blocks)
    {
        switch (lines.length)
        {
        default:
            play_sound ("land");
            break;
        case 1:
            play_sound ("lines1");
            break;
        case 2:
            play_sound ("lines2");
            break;
        case 3:
        case 4:
            play_sound ("lines3");
            break;
        }

        /* Remove the moving shape */
        shape.destroy ();
        shape = null;
        if (shape_shadow != null)
            shape_shadow.destroy ();
        shape_shadow = null;
        shape_blocks.remove_all ();

        n_lines_destroyed = lines.length;

        /* Land the shape blocks */
        foreach (var block in game.shape.blocks)
        {
            var actor = new BlockActor (block, block_textures[block.color]);
            playing_field.add (actor);
            blocks.insert (block, actor);
            actor.set_size (cell_size, cell_size);
            actor.set_position (block.x * cell_size, (block.y - n_lines_destroyed) * cell_size);
        }

        /* Explode blocks */
        foreach (var block in line_blocks)
        {
            var actor = blocks.lookup (block);
            actor.explode ();
            blocks.remove (block);
        }

        /* Drop blocks that have moved */
        if (lines.length > 0)
        {
            for (var x = 0; x < game.width; x++)
            {
                for (var y = 0; y < game.height; y++)
                {
                    var block = game.blocks[x, y];
                    if (block == null)
                        continue;

                    var actor = blocks.lookup (block);

                    actor.save_easing_state ();
                    actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_BOUNCE);
                    actor.set_easing_duration ((int) (300 * Math.sqrt (n_lines_destroyed)));
                    actor.set_position ((float) block.x * cell_size, (float) block.y * cell_size);
                    actor.restore_easing_state ();
                }
            }
        }
    }

    private void size_allocate_cb (Gtk.Widget widget, Gtk.Allocation allocation)
    {
        if (game == null)
            return;

        foreach (var texture in block_textures)
            texture.set_size (cell_size, cell_size);

        var iter = HashTableIter<Block, BlockActor> (blocks);
        while (true)
        {
            Block block;
            BlockActor actor;
            if (!iter.next (out block, out actor))
                break;
            actor.set_size (cell_size, cell_size);
            actor.set_position (block.x * cell_size, block.y * cell_size);
        }
        var shape_iter = HashTableIter<Block, BlockActor> (shape_blocks);
        while (true)
        {
            Block block;
            BlockActor actor;
            if (!shape_iter.next (out block, out actor))
                break;
            actor.set_size (cell_size, cell_size);
            actor.set_position (block.x * cell_size, block.y * cell_size);
        }
        if (shape != null)
            shape.set_position (game.shape.x * cell_size, game.shape.y * cell_size);
        update_shadow ();

        text_overlay.set_size (get_allocated_width (), get_allocated_height ());
        text_overlay.get_parent ().set_child_above_sibling (text_overlay, null);

        playing_field.set_size (game.width * cell_size, game.height * cell_size);
        playing_field.set_position ((get_allocated_width () - playing_field.get_width ()) * 0.5f,
                                    get_allocated_height () - playing_field.get_height ());
    }

    private void pause_changed_cb ()
    {
        update_message ();
    }

    private void game_complete_cb ()
    {
        play_sound ("gameover");
        update_message ();
    }

    private void update_message ()
    {
        if (game.paused)
            text_overlay.text = _("Paused");
        else if (game.game_over)
            text_overlay.text = _("Game Over");
        else
            text_overlay.text = null;
    }

    /*\
    * * Sound
    \*/

    /* false to play sound effects */
    internal bool mute { internal set; private get; default = true; }

    private GSound.Context sound_context;
    private SoundContextState sound_context_state = SoundContextState.INITIAL;

    private enum SoundContextState
    {
        INITIAL,
        WORKING,
        ERRORED
    }

    private void init_sound ()
     // requires (sound_context_state == SoundContextState.INITIAL)
    {
        try
        {
            sound_context = new GSound.Context ();
            sound_context_state = SoundContextState.WORKING;
        }
        catch (Error e)
        {
            warning (e.message);
            sound_context_state = SoundContextState.ERRORED;
        }
    }

    private void play_sound (string name)
    {
        if (!mute)
        {
            if (sound_context_state == SoundContextState.INITIAL)
                init_sound ();
            if (sound_context_state == SoundContextState.WORKING)
                _play_sound (name, sound_context);
        }
    }

    private static void _play_sound (string _name, GSound.Context sound_context)
    {
        string name = _name + ".ogg";
        string path = Path.build_filename (SOUND_DIRECTORY, name);
        try
        {
            sound_context.play_simple (null, GSound.Attribute.MEDIA_NAME, name,
                                             GSound.Attribute.MEDIA_FILENAME, path);
        }
        catch (Error e)
        {
            warning (e.message);
        }
    }
}

private class BlockActor : Clutter.Clone
{
    public Block block;

    public BlockActor (Block block, Clutter.Actor texture)
    {
        Object (source: texture);
        this.block = block;
    }

    public void explode ()
    {
        get_parent ().set_child_above_sibling (this, null);

        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUINT);
        set_easing_duration (720);
        set_opacity (0);
        set_scale (2f, 2f);
        transitions_completed.connect (explode_complete_cb);
        restore_easing_state ();
    }

    private void explode_complete_cb ()
    {
        destroy ();
    }
}

private class TextOverlay : Clutter.CairoTexture
{
    private string? _text = null;
    public string text
    {
        get { return _text; }
        set { _text = value; invalidate (); }
    }

    public TextOverlay ()
    {
        auto_resize = true;
    }

    protected override bool draw (Cairo.Context cr)
    {
        clear ();

        if (text == null)
            return false;

        /* Center coordinates */
        uint w, h;
        get_surface_size (out w, out h);
        cr.translate (w / 2, h / 2);

        var desc = Pango.FontDescription.from_string ("Sans");

        var layout = Pango.cairo_create_layout (cr);
        layout.set_text (text, -1);

        var dummy_layout = layout.copy ();
        dummy_layout.set_font_description (desc);
        int lw, lh;
        dummy_layout.get_size (out lw, out lh);

        desc.set_absolute_size (((float) lh / lw) * Pango.SCALE * w * 0.7);
        layout.set_font_description (desc);

        layout.get_size (out lw, out lh);
        cr.move_to (-((double)lw / Pango.SCALE) / 2, -((double)lh / Pango.SCALE) / 2);
        Pango.cairo_layout_path (cr, layout);
        cr.set_source_rgb (0.333333333333, 0.341176470588, 0.32549019607);

        /* A linewidth of 2 pixels at the default size. */
        cr.set_line_width (width / 100.0);
        cr.stroke_preserve ();

        cr.set_source_rgb (1.0, 1.0, 1.0);
        cr.fill ();

        return false;
    }
}

public class BlockTexture : Clutter.CairoTexture
{
    private int color;
    private string? _theme = null;
    public string? theme
    {
        get { return _theme; }
        set
        {
            if (_theme == value)
                return;
            _theme = value;
            invalidate ();
        }
    }

    public BlockTexture (int color)
    {
        auto_resize = true;
        this.color = color.clamp (0, 6);
    }

    protected override bool draw (Cairo.Context cr)
    {
        clear ();

        uint w, h;
        get_surface_size (out w, out h);
        cr.scale (w, h);

        switch (theme)
        {
        default:
        case "plain":
            draw_plain (cr);
            break;
        case "clean":
            draw_clean (cr);
            break;
        case "tangoflat":
            draw_tango (cr, false);
            break;
        case "tangoshaded":
            draw_tango (cr, true);
            break;
        }

        return false;
    }

    private void draw_plain (Cairo.Context cr)
    {
        const double colors[32] =
        {
            1.0, 0.0, 0.0,
            0.0, 1.0, 0.0,
            0.0, 0.0, 1.0,
            1.0, 1.0, 1.0,
            1.0, 1.0, 0.0,
            1.0, 0.0, 1.0,
            0.0, 1.0, 1.0
        };

        cr.set_source_rgb (colors[color * 3], colors[color * 3 + 1], colors[color * 3 + 2]);
        cr.paint ();
    }

    private void draw_rounded_rectangle (Cairo.Context cr, double x, double y, double w, double h, double r)
    {
        cr.move_to (x + r, y);
        cr.line_to (x + w - r, y);
        cr.curve_to (x + w - (r/2), y, x + w, y + r / 2, x + w, y + r);
        cr.line_to (x + w, y + h - r);
        cr.curve_to (x + w, y + h - r / 2, x + w - r / 2, y + h, x + w - r, y + h);
        cr.line_to (x + r, y + h);
        cr.curve_to (x + r / 2, y + h, x, y + h - r / 2, x, y + h - r);
        cr.line_to (x, y + r);
        cr.curve_to (x, y + r / 2, x + r / 2, y, x + r, y);
    }

    private void draw_clean (Cairo.Context cr)
    {
        /* The colors, first the lighter then the darker fill (for the gradient)
           and then the stroke color  */
        const double colors[72] =
        {
            0.780392156863, 0.247058823529, 0.247058823529,
            0.713725490196, 0.192156862745, 0.192156862745,
            0.61568627451, 0.164705882353, 0.164705882353, /* red */

            0.552941176471, 0.788235294118, 0.32549019607,
            0.474509803922, 0.713725490196, 0.243137254902,
            0.388235294118, 0.596078431373, 0.18431372549, /* green */

            0.313725490196, 0.450980392157, 0.623529411765,
            0.239215686275, 0.345098039216, 0.474509803922,
            0.21568627451, 0.313725490196, 0.435294117647, /* blue */

            1.0, 1.0, 1.0,
            0.909803921569, 0.909803921569, 0.898039215686,
            0.701960784314, 0.701960784314, 0.670588235294, /* white */

            0.945098039216, 0.878431372549, 0.321568627451,
            0.929411764706, 0.839215686275, 0.113725490196,
            0.760784313725, 0.682352941176, 0.0274509803922, /* yellow */

            0.576470588235, 0.364705882353, 0.607843137255,
            0.443137254902, 0.282352941176, 0.46666666666,
            0.439215686275, 0.266666666667, 0.46666666666, /* purple */

            0.890196078431, 0.572549019608, 0.258823529412,
            0.803921568627, 0.450980392157, 0.101960784314,
            0.690196078431, 0.388235294118, 0.0901960784314, /* orange */

            0.392156862745, 0.392156862745, 0.392156862745,
            0.262745098039, 0.262745098039, 0.262745098039,
            0.21568627451, 0.235294117647, 0.23921568627 /* grey */
        };

        /* Layout the block */
        draw_rounded_rectangle (cr, 0.05, 0.05, 0.9, 0.9, 0.05);

        /* Draw outline */
        cr.set_source_rgb (colors[color * 9 + 6], colors[color * 9 + 7], colors[color * 9 + 8]);
        cr.set_line_width (0.1);
        cr.stroke_preserve ();

        /* Fill with gradient */
        var pat = new Cairo.Pattern.linear (0.35, 0, 0.55, 0.9);
        pat.add_color_stop_rgb (0.0, colors[color * 9], colors[color * 9 + 1], colors[color * 9 + 2]);
        pat.add_color_stop_rgb (1.0, colors[color * 9 + 3], colors[color * 9 + 4], colors[color * 9 + 5]);
        cr.set_source (pat);
        cr.fill ();
    }

    private void draw_tango (Cairo.Context cr, bool use_gradients)
    {
        /* The following garbage is derived from the official tango style guide */
        const double colors[72] =
        {
            0.93725490196078431, 0.16078431372549021, 0.16078431372549021,
            0.8, 0.0, 0.0,
            0.64313725490196083, 0.0, 0.0, /* red */

            0.54117647058823526, 0.88627450980392153, 0.20392156862745098,
            0.45098039215686275, 0.82352941176470584, 0.086274509803921567,
            0.30588235294117649, 0.60392156862745094, 0.023529411764705882, /* green */

            0.44705882352941179, 0.62352941176470589, 0.81176470588235294,
            0.20392156862745098, 0.396078431372549, 0.64313725490196083,
            0.12549019607843137, 0.29019607843137257, 0.52941176470588236, /* blue */

            0.93333333333333335, 0.93333333333333335, 0.92549019607843142,
            0.82745098039215681, 0.84313725490196079, 0.81176470588235294,
            0.72941176470588232, 0.74117647058823533, 0.71372549019607845, /* white */

            0.9882352941176471, 0.9137254901960784, 0.30980392156862746,
            0.92941176470588238, 0.83137254901960789, 0.0,
            0.7686274509803922, 0.62745098039215685, 0.0, /* yellow */

            0.67843137254901964, 0.49803921568627452, 0.6588235294117647,
            0.45882352941176469, 0.31372549019607843, 0.4823529411764706,
            0.36078431372549019, 0.20784313725490197, 0.4, /* purple */

            0.9882352941176471, 0.68627450980392157, 0.24313725490196078,
            0.96078431372549022, 0.47450980392156861, 0.0,
            0.80784313725490198, 0.36078431372549019, 0.0, /* orange (replacing cyan) */

            0.33, 0.34, 0.32,
            0.18, 0.2, 0.21,
            0.10, 0.12, 0.13 /* grey */
        };

        if (use_gradients)
        {
             var pat = new Cairo.Pattern.linear (0.35, 0, 0.55, 0.9);
             pat.add_color_stop_rgb (0.0, colors[color * 9], colors[color * 9 + 1], colors[color * 9 + 2]);
             pat.add_color_stop_rgb (1.0, colors[color * 9 + 3], colors[color * 9 + 4], colors[color * 9 + 5]);
             cr.set_source (pat);
        }
        else
             cr.set_source_rgb (colors[color * 9], colors[color * 9 + 1], colors[color * 9 + 2]);

        draw_rounded_rectangle (cr, 0.05, 0.05, 0.9, 0.9, 0.2);
        cr.fill_preserve ();  /* fill with shaded gradient */

        cr.set_source_rgb (colors[color * 9 + 6], colors[color * 9 + 7], colors[color * 9 + 8]);

        /* Add darker outline */
        cr.set_line_width (0.1);
        cr.stroke ();

        draw_rounded_rectangle (cr, 0.15, 0.15, 0.7, 0.7, 0.08);
        if (use_gradients)
        {
            var pat = new Cairo.Pattern.linear (-0.3, -0.3, 0.8, 0.8);
            /* yellow and white blocks need a brighter highlight */
            switch (color)
            {
            case 3:
            case 4:
                pat.add_color_stop_rgba (0.0, 1.0, 1.0, 1.0, 1.0);
                pat.add_color_stop_rgba (1.0, 1.0, 1.0, 1.0, 0.0);
                break;
            default:
                pat.add_color_stop_rgba (0.0, 0.9295, 0.9295, 0.9295, 1.0);
                pat.add_color_stop_rgba (1.0, 0.9295, 0.9295, 0.9295, 0.0);
                break;
            }
            cr.set_source (pat);
        }
        else
            cr.set_source_rgba (1.0, 1.0, 1.0, 0.35);

        /* Add inner edge highlight */
        cr.stroke ();
    }
}
