/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class GameView : Gtk.Widget {
    static construct {
        set_css_name ("game-view");
    }

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
            clear_blocks ();

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
                        var widget = new BlockWidget (block, theme);
                        widget.color = block.color;
                        blocks.insert (block, widget);
                        add_block_widget (widget);
                    }
                }
            }

            set_size_request (_game.width * 190 / _game.height, 190);
            update_message ();
        }
    }

    private string? _theme;
    /* Theme to use */
    public string theme
    {
        get { return _theme; }
        set
        {
            if (_theme != null)
                this.remove_css_class ("theme-" + _theme);

            this.add_css_class ("theme-" + value);

            Block block;
            BlockWidget widget;

            var iter = HashTableIter<Block, BlockWidget> (blocks);
            while (true)
            {
                if (!iter.next (out block, out widget))
                    break;
                widget.theme = value;
            }

            iter = HashTableIter<Block, BlockWidget> (shape_blocks);
            while (true)
            {
                if (!iter.next (out block, out widget))
                    break;
                widget.theme = value;
            }

            iter = HashTableIter<Block, BlockWidget> (shadow_blocks);
            while (true)
            {
                if (!iter.next (out block, out widget))
                    break;
                widget.theme = value;
            }

            _theme = value;
        }
    }

    private bool _show_shadow = false;
    public bool show_shadow
    {
        get { return _show_shadow; }
        set { _show_shadow = value; queue_allocate (); }
    }

    /* Overlay to draw messages on */
    private TextOverlay text_overlay;

    /* Blocks */
    private HashTable<Block, BlockWidget> blocks;
    private HashTable<Block, BlockWidget> shape_blocks;
    private HashTable<Block, BlockWidget> shadow_blocks;

    /* Number of lines destroyed (required for earthquake effect) */
    private int n_lines_destroyed;

    private int cell_size
    {
        get
        {
            if (game != null)
                return int.min (get_width () / game.width, get_height () / game.height);
            else
                return 0;
        }
    }

    public GameView ()
    {
        text_overlay = new TextOverlay ();
        text_overlay.set_parent (this);

        blocks = new HashTable<Block, BlockWidget> (direct_hash, direct_equal);
        shape_blocks = new HashTable<Block, BlockWidget> (direct_hash, direct_equal);
        shadow_blocks = new HashTable<Block, BlockWidget> (direct_hash, direct_equal);
    }

    protected override void size_allocate (int width, int height, int baseline) {
        var block_width = width / game.width;
        var block_height = height / game.height;

        var block_widget = get_first_child () as BlockWidget;
        while (block_widget != null) {
            // The blocks are always the first children, everything else comes after
            Graphene.Point pos = Graphene.Point ();
            bool show = true;

            if (shape_blocks.lookup (block_widget.block) == block_widget)
            {
                pos.x = (game.shape.x + block_widget.block.x) * block_width;
                pos.y = (game.shape.y + block_widget.block.y) * block_height;
            }
            else if (shadow_blocks.lookup (block_widget.block) == block_widget)
            {
                if (show_shadow)
                {
                    pos.x = (game.shape.x + block_widget.block.x) * block_width;
                    pos.y = (game.shadow_y + block_widget.block.y) * block_height;
                }
                else
                {
                    show = false;
                }
            }
            else
            {
                // Regular blocks or blocks that are currently animating out of view
                pos.x = block_widget.block.x * block_width;
                pos.y = block_widget.block.y * block_height;
            }

            if (show)
            {
                int min_width;
                int min_height;
                int actual_width;
                int actual_height;

                block_widget.measure (Gtk.Orientation.VERTICAL, -1, out min_width, null, null, null);
                actual_width = int.max (min_width, block_width);

                block_widget.measure (Gtk.Orientation.HORIZONTAL, actual_width, out min_height, null, null, null);
                actual_height = int.max (min_height, block_height);

                // adjust pos to center the block if it is bigger (animating)
                pos.x -= (actual_width - block_width) / 2;
                pos.y -= (actual_height - block_height) / 2;
                var transform = new Gsk.Transform ().translate (pos);

                block_widget.allocate (actual_width, actual_height, -1, transform);
            }

            block_widget = block_widget.get_next_sibling () as BlockWidget;
        }

        // Text overlay
        var pos = Graphene.Point () {
            x = 0,
            y = 0
        };

        var transform = new Gsk.Transform ().translate (pos);
        text_overlay.measure (Gtk.Orientation.VERTICAL, width, null, null, null, null);
        text_overlay.allocate (width, height, -1, transform);
    }

    private void add_block_widget (BlockWidget widget) {
        widget.insert_before (this, text_overlay);
    }

    private void clear_blocks () {
        Block block;
        BlockWidget widget;
        HashTableIter<Block, BlockWidget> iter;

        iter = HashTableIter<Block, BlockWidget> (blocks);
        while (true)
        {
            if (!iter.next (out block, out widget))
                break;
            widget.unparent ();
        }

        iter = HashTableIter<Block, BlockWidget> (shape_blocks);
        while (true)
        {
            if (!iter.next (out block, out widget))
                break;
            widget.unparent ();
        }

        iter = HashTableIter<Block, BlockWidget> (shadow_blocks);
        while (true)
        {
            if (!iter.next (out block, out widget))
                break;
            widget.unparent ();
        }

        blocks.remove_all ();
        shape_blocks.remove_all ();
        shadow_blocks.remove_all ();
    }

    protected override void dispose () {
        clear_blocks ();
        text_overlay.unparent ();
        base.dispose ();
    }

    private void shape_added_cb ()
    {
        if (game.shape != null)
        {
            foreach (var block in game.shape.blocks)
            {
                var widget = new BlockWidget (block, theme);
                shape_blocks.insert (block, widget);
                add_block_widget (widget);

                // Shadow blocks
                if (show_shadow)
                {
                    var shadow_widget = new BlockWidget (block, theme);
                    shadow_widget.add_css_class ("shadow");
                    shadow_blocks.insert (block, shadow_widget);
                    add_block_widget (shadow_widget);
                }
            }
        }

        queue_allocate();
    }

    private void shape_moved_cb ()
    {
        queue_allocate ();
        play_sound ("slide");
    }

    private void shape_dropped_cb ()
    {
        queue_allocate ();
    }

    private void shape_rotated_cb ()
    {
        queue_allocate ();
        play_sound ("turn");
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

        n_lines_destroyed = lines.length;

        var shape_iter = HashTableIter<Block, BlockWidget> (shape_blocks);
        while (true)
        {
            Block block;
            BlockWidget widget;
            if (!shape_iter.next (out block, out widget))
                break;
            widget.unparent ();
        }

        shape_blocks.remove_all ();

        var shadow_iter = HashTableIter<Block, BlockWidget> (shadow_blocks);
        while (true)
        {
            Block block;
            BlockWidget widget;
            if (!shadow_iter.next (out block, out widget))
                break;
            widget.unparent ();
        }

        shadow_blocks.remove_all ();

        /* Land the shape blocks */
        foreach (var block in game.shape.blocks)
        {
            var widget = new BlockWidget (block, theme);
            blocks.insert (block, widget);
            add_block_widget (widget);
        }

        /* Explode blocks */
        foreach (var block in line_blocks)
        {
            var widget = blocks.lookup (block);
            // reorder exploding widgets to be on top
            add_block_widget (widget);

            // animate widgets
            blocks.remove (block);
            widget.explode ();
        }

        queue_allocate ();
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
        {
            text_overlay.text = _("Paused");
            text_overlay.visible = true;
        }
        else if (game.game_over)
        {
            text_overlay.text = _("Game Over");
            text_overlay.visible = true;
        }
        else
            text_overlay.visible = false;
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

private class TextOverlay : Gtk.DrawingArea
{
    private string? _text = null;
    public string text
    {
        get { return _text; }
        set {
            _text = value;
            if (value == _("Paused"))
                this.add_css_class ("text-overlay");
            else
                this.remove_css_class ("text-overlay");
            queue_draw ();
        }
    }

    public TextOverlay ()
    {
        set_draw_func (draw);
    }

    protected void draw (Gtk.DrawingArea area, Cairo.Context cr, int width, int height)
    {
        if (text == null)
            return;

        int w = get_width ();
        int h = get_height ();
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
    }
}

public class BlockWidget: Gtk.Widget
{
    static construct {
        set_css_name ("block");
    }


    private string? _theme = null;
    public string? theme
    {
        get { return _theme; }
        set
        {
            if (_theme == value)
                return;
            _theme = value;
            drawing_area.queue_draw ();
            queue_draw ();
        }
    }

    private int _color = -1;
    public int color {
        get { return _color; }
        set {
            if (_color == value)
                return;

            var old_color_class = "color-%d".printf (_color);
            this.remove_css_class (old_color_class);

            var new_color = value.clamp (0, 6);
            var new_color_class = "color-%d".printf (new_color);
            this.add_css_class (new_color_class);
            _color = value;
        }
    }

    public Block block;
    private Gtk.DrawingArea drawing_area;

    public BlockWidget (Block block, string? theme)
    {
        drawing_area = new Gtk.DrawingArea ();
        drawing_area.set_draw_func (draw);
        drawing_area.set_parent (this);

        this.block = block;
        this.color = block.color;
        can_target = false;
        if (theme != null)
            this.theme = theme;
        else
            this.theme = "plain";
    }

    protected override void size_allocate (int width, int height, int baseline) {
        drawing_area.measure (Gtk.Orientation.HORIZONTAL, width, null, null, null, null);
        var transform = new Gsk.Transform ().translate (Graphene.Point ());
        drawing_area.allocate (width, height, -1, transform);
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        switch (theme) {
        case "modern":
            snapshot_modern (snapshot);
            break;
        default:
            base.snapshot (snapshot);
            break;
        }
    }

    private void snapshot_modern (Gtk.Snapshot snapshot) {
        // Colors from GNOME color scheme
        const float colors[21] =
        {
            0.929411765f, 0.2f, 0.231372549f,
            0.341176471f, 0.890196078f, 0.537254902f,
            0.384313725f, 0.62745098f, 0.917647059f,
            0.964705882f, 0.960784314f, 0.956862745f,
            0.97254902f, 0.894117647f, 0.360784314f,
            0.752941176f, 0.380392157f, 0.796078431f,
            1.0f, 0.639215686f, 0.282352941f
        };

        float border_width = 0.05f;

        var color = Gdk.RGBA () {
            red = colors[color * 3],
            green = colors[color * 3 + 1],
            blue = colors[color * 3 + 2],
            alpha = 1.0f
        };

        var rect = Graphene.Rect () {
            origin = Graphene.Point () {
                x = border_width * get_width (),
                y = border_width * get_height ()
            },
            size = Graphene.Size () {
                width = (1 - 2 * border_width) * get_width (),
                height = (1 - 2 * border_width) * get_height ()
            }
        };

        snapshot.append_color (color, rect);
    }

    private int animation_size_begin = 0;

    public void explode ()
    {
        var target = new Adw.CallbackAnimationTarget (explode_animation_cb);
        var animation = new Adw.TimedAnimation (this, 0.0, 1.0, 720, target);
        animation.set_easing (Adw.Easing.EASE_OUT_QUINT);
        animation.done.connect (explode_complete_cb);
        animation_size_begin = get_width ();
        animation.play ();
    }

    private void explode_animation_cb (double val) {
        opacity = 1 - val;
        int size = (int)((val + 1) * animation_size_begin);
        set_size_request (size, size);
    }

    private void explode_complete_cb (Adw.Animation animation)
    {
        unparent ();
    }

    public void draw (Gtk.DrawingArea area, Cairo.Context cr, int width, int height)
    {
        cr.scale (width, height);

        switch (theme)
        {
        default:
        case "plain":
            draw_plain (cr, width, height);
            break;
        case "clean":
            draw_clean (cr, width, height);
            break;
        case "tangoflat":
            draw_tango (cr, width, height, false);
            break;
        case "tangoshaded":
            draw_tango (cr, width, height, true);
            break;
        }
    }

    private void draw_plain (Cairo.Context cr, int width, int height)
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

    private void draw_clean (Cairo.Context cr, int width, int height)
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

    private void draw_tango (Cairo.Context cr, int width, int height, bool use_gradients)
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
        else {
             cr.set_source_rgb (colors[color * 9], colors[color * 9 + 1], colors[color * 9 + 2]);
        }

        draw_rounded_rectangle (cr, 0.05, 0.05, 0.9, 0.9, 0.2);
        cr.fill_preserve ();  // fill with shaded gradient

        cr.set_source_rgb (colors[color * 9 + 6], colors[color * 9 + 7], colors[color * 9 + 8]);

        // Add darker outline
        cr.set_line_width (0.1);
        cr.stroke ();

        draw_rounded_rectangle (cr, 0.15, 0.15, 0.7, 0.7, 0.08);
        if (use_gradients)
        {
            var pat = new Cairo.Pattern.linear (-0.3, -0.3, 0.8, 0.8);
            // yellow and white blocks need a brighter highlight
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

        // Add inner edge highlight
        cr.stroke ();
    }
}

