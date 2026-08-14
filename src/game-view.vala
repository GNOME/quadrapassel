/* game-view.vala
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
            _game.shape_removed.connect (shape_removed_cb);
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
                        var widget = new BlockWidget (block);
                        widget.add_css_class (theme);
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
            foreach (var widget in get_block_widgets ())
            {
                widget.remove_css_class (_theme);
                widget.add_css_class (value);
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
    private Gtk.Label text_overlay;

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

    /*\
    * * Sound
    \*/

    /* false to play sound effects */
    internal bool mute { internal set; private get; default = true; }

    internal Games.Sounds sounds;

    private void play_sound (string name)
    {
        if (!mute)
        {
            sounds.play (name + ".ogg");
        }
    }

    public GameView ()
    {
        text_overlay = new Gtk.Label (null);
        text_overlay.set_parent (this);
        text_overlay.add_css_class ("title-1");

        blocks = new HashTable<Block, BlockWidget> (direct_hash, direct_equal);
        shape_blocks = new HashTable<Block, BlockWidget> (direct_hash, direct_equal);
        shadow_blocks = new HashTable<Block, BlockWidget> (direct_hash, direct_equal);

        try
        {
            sounds = new Games.Sounds (SOUND_DIRECTORY);
        }
        catch (Error e)
        {
            critical ("Failed to create sounds: %s".printf (e.message));
            mute = true;
        }
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

    protected override void measure (Gtk.Orientation orientation,
                                     int for_size,
                                     out int minimum,
                                     out int natural,
                                     out int minimum_baseline,
                                     out int natural_baseline)
    {
        if (orientation == Gtk.Orientation.VERTICAL)
        {
            minimum = 100;
            natural = 400;
        }
        else
        {
            minimum = 50;
            natural = 200;
        }
        minimum_baseline = natural_baseline = -1;
    }

    private void add_block_widget (BlockWidget widget) {
        widget.insert_before (this, text_overlay);
    }

    private BlockWidget[] get_block_widgets () {
        Block block;
        BlockWidget widget;
        HashTableIter<Block, BlockWidget> iter;
        var widgets = new BlockWidget[0];

        iter = HashTableIter<Block, BlockWidget> (blocks);
        while (true)
        {
            if (!iter.next (out block, out widget))
                break;
            widgets += widget;
        }

        iter = HashTableIter<Block, BlockWidget> (shape_blocks);
        while (true)
        {
            if (!iter.next (out block, out widget))
                break;
            widgets += widget;
        }

        iter = HashTableIter<Block, BlockWidget> (shadow_blocks);
        while (true)
        {
            if (!iter.next (out block, out widget))
                break;
            widgets += widget;
        }

        return widgets;
    }

    private void clear_blocks () {
        foreach (var widget in get_block_widgets ())
            widget.unparent ();

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
                var widget = new BlockWidget (block);
                widget.add_css_class (theme);
                shape_blocks.insert (block, widget);
                add_block_widget (widget);

                // Shadow blocks
                if (show_shadow)
                {
                    var shadow_widget = new BlockWidget (block);
                    shadow_widget.add_css_class (theme);
                    shadow_widget.add_css_class ("shadow");
                    shadow_blocks.insert (block, shadow_widget);
                    add_block_widget (shadow_widget);
                }
            }
        }

        queue_allocate ();
    }

    private void shape_moved_cb ()
    {
        queue_allocate ();
        play_sound ("slide");
    }

    private void shape_removed_cb ()
    {
        remove_shape_blocks ();
        queue_allocate ();
    }

    private void remove_shape_blocks ()
    {
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

        remove_shape_blocks ();

        /* Land the shape blocks */
        foreach (var block in game.shape.blocks)
        {
            var widget = new BlockWidget (block);
            widget.add_css_class (theme);
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
            text_overlay.label = _("Paused");
            text_overlay.visible = true;
            foreach (var widget in get_block_widgets ())
                widget.visible = false;
        }
        else if (game.game_over)
        {
            text_overlay.label = _("Game Over");
            text_overlay.visible = true;
            foreach (var widget in get_block_widgets ())
                widget.visible = false;
        }
        else
        {
            text_overlay.visible = false;
            foreach (var widget in get_block_widgets ())
                widget.visible = true;
        }
    }
}

public class BlockWidget: Gtk.Widget
{
    static construct {
        set_css_name ("block");
    }

    public Block block;

    public BlockWidget (Block block)
    {
        this.block = block;
        switch (block.color)
        {
            case 0:
                this.add_css_class ("red");
                break;

            case 1:
                this.add_css_class ("green");
                break;

            case 2:
                this.add_css_class ("blue");
                break;

            case 3:
                this.add_css_class ("gray");
                break;

            case 4:
                this.add_css_class ("yellow");
                break;

            case 5:
                this.add_css_class ("purple");
                break;

            case 6:
                this.add_css_class ("orange");
                break;
        }

        can_target = false;
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
}
