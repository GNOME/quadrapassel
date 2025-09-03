/*
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2009 Lubomir Rintel <lkundrak@v3.sk>
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

const int NCOLORS = 7;


/* When the player holds either the left or right key, the game will begin automatically moving the tetrominos in that direction.
 * To accomplish that in a way expected by the player, there is 2 important delay. The "activation" delay and the "interval" delay.(These are made up names to explain).
 * 
 * The "activation" delay is the amount of time it takes until de auto move starts.
 * The "interval" delay is the speed of the auto move.
 *
 * The interval delay is naturally (i think) expected by the players to be faster than the activation period/delay.
 * My subjective favorite values are 200 for activation and 40 for interval.
 */
const int AUTOMOVE_ACTIVATION_TIME = 200; // 200
const int AUTOMOVE_INTERVAL = 40; // 40




private const int block_table[448] =
{

    /* *** */
    /* *   */
    0, 0, 1, 0,
    1, 1, 1, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,

    1, 1, 0, 0,
    0, 1, 0, 0,
    0, 1, 0, 0,
    0, 0, 0, 0,

    0, 0, 0, 0,
    1, 1, 1, 0,
    1, 0, 0, 0,
    0, 0, 0, 0,

    0, 1, 0, 0,
    0, 1, 0, 0,
    0, 1, 1, 0,
    0, 0, 0, 0,

    /* *** */
    /*   * */
    1, 0, 0, 0,
    1, 1, 1, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,

    0, 1, 0, 0,
    0, 1, 0, 0,
    1, 1, 0, 0,
    0, 0, 0, 0,

    0, 0, 0, 0,
    1, 1, 1, 0,
    0, 0, 1, 0,
    0, 0, 0, 0,

    0, 1, 1, 0,
    0, 1, 0, 0,
    0, 1, 0, 0,
    0, 0, 0, 0,

    /* *** */
    /*  *  */
    0, 1, 0, 0,
    1, 1, 1, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,

    0, 1, 0, 0,
    1, 1, 0, 0,
    0, 1, 0, 0,
    0, 0, 0, 0,

    0, 0, 0, 0,
    1, 1, 1, 0,
    0, 1, 0, 0,
    0, 0, 0, 0,

    0, 1, 0, 0,
    0, 1, 1, 0,
    0, 1, 0, 0,
    0, 0, 0, 0,

    /*  ** */
    /* **  */

    0, 0, 0, 0,
    0, 1, 1, 0,
    1, 1, 0, 0,
    0, 0, 0, 0,

    0, 1, 0, 0,
    0, 1, 1, 0,
    0, 0, 1, 0,
    0, 0, 0, 0,

    0, 0, 0, 0,
    0, 1, 1, 0,
    1, 1, 0, 0,
    0, 0, 0, 0,

    0, 1, 0, 0,
    0, 1, 1, 0,
    0, 0, 1, 0,
    0, 0, 0, 0,

    /* **  */
    /*  ** */

    0, 0, 0, 0,
    1, 1, 0, 0,
    0, 1, 1, 0,
    0, 0, 0, 0,

    0, 0, 1, 0,
    0, 1, 1, 0,
    0, 1, 0, 0,
    0, 0, 0, 0,

    0, 0, 0, 0,
    1, 1, 0, 0,
    0, 1, 1, 0,
    0, 0, 0, 0,

    0, 0, 1, 0,
    0, 1, 1, 0,
    0, 1, 0, 0,
    0, 0, 0, 0,

    /* **** */
    0, 0, 0, 0,
    1, 1, 1, 1,
    0, 0, 0, 0,
    0, 0, 0, 0,

    0, 1, 0, 0,
    0, 1, 0, 0,
    0, 1, 0, 0,
    0, 1, 0, 0,

    0, 0, 0, 0,
    1, 1, 1, 1,
    0, 0, 0, 0,
    0, 0, 0, 0,

    0, 1, 0, 0,
    0, 1, 0, 0,
    0, 1, 0, 0,
    0, 1, 0, 0,

    /* ** */
    /* ** */
    0, 0, 0, 0,
    0, 1, 1, 0,
    0, 1, 1, 0,
    0, 0, 0, 0,

    0, 0, 0, 0,
    0, 1, 1, 0,
    0, 1, 1, 0,
    0, 0, 0, 0,

    0, 0, 0, 0,
    0, 1, 1, 0,
    0, 1, 1, 0,
    0, 0, 0, 0,

    0, 0, 0, 0,
    0, 1, 1, 0,
    0, 1, 1, 0,
    0, 0, 0, 0
};

public class Block : Object
{
    /* Location of block */
    public int x;
    public int y;

    /* Color of block */
    public int color;

    public Block copy ()
    {
        var b = new Block ();
        b.x = x;
        b.y = y;
        b.color = color;
        return b;
    }
}

public class Shape : Object
{
    /* Location of shape */
    public int x;
    public int y;

    /* Rotation angle */
    public int rotation;

    /* Piece type */
    public int type;

    /* Blocks that make up this shape */
    public List<Block> blocks = null;

    public Shape copy ()
    {
        var s = new Shape ();
        s.x = x;
        s.y = y;
        s.rotation = rotation;
        s.type = type;
        foreach (var b in blocks)
            s.blocks.append (b.copy ());
        return s;
    }
}

public class Game : Object
{
    /* Falling shape */
    public Shape? shape = null;

    /* Next shape to be used */
    public Shape? next_shape = null;

    /* Placed blocks */
    public Block[,] blocks;

    public int width { get { return blocks.length[0]; } }
    public int height { get { return blocks.length[1]; } }

    /* Number of lines that have been destroyed */
    public int n_lines_destroyed = 0;

    /* Game score */
    public int score = 0;

    /* The difficulty of the game */
    public int difficulty = 0;

    /* true if should pick difficult blocks to place */
    private bool pick_difficult_blocks = false;

    /* The current level */
    public int level { get { return (difficulty + 1) + (n_lines_destroyed / 10); } }

    /* The direction we are moving */
    private int fast_move_direction = 0;

    /* Timer to animate moving fast */
    private uint fast_move_timeout = 0;

    /* true if we are in fast forward mode */
    private bool fast_forward = false;

    /* Timer to animate block drops */
    private uint drop_timeout = 0;

    /* true if the game has started */
    private bool has_started = false;

    /* true if games is paused */
    private bool _paused = false;
    public bool paused
    {
        get { return _paused; }
        set
        {
            _paused = value;
            if (has_started && !game_over)
                setup_drop_timer ();
            pause_changed ();
        }
    }

    /* The y co-ordinate of the shadow of the falling shape */
    public int shadow_y
    {
        get
        {
            if (shape == null)
                return 0;

            var d = 0;
            var g = copy ();
            while (g.move_shape (0, 1, 0))
                d++;

            return shape.y + d;
        }
    }

    public bool game_over = false;

    public signal void started ();
    public signal void shape_added ();
    public signal void shape_moved ();
    public signal void shape_dropped ();
    public signal void shape_rotated ();
    public signal void shape_landed (int[] lines, List<Block> line_blocks);
    public signal void pause_changed ();
    public signal void complete ();

    public Game (int lines = 20, int columns = 10, int difficulty = 0, int filled_lines = 0, int fill_prob = 5, bool pick_difficult_blocks = false)
    {
        this.difficulty = difficulty;
        this.pick_difficult_blocks = pick_difficult_blocks;

        blocks = new Block[columns, lines];
        /* Start with some shape_landed-filled spaces */
        for (var y = 0; y < height; y++)
        {
            /* Pick at least one column to be empty */
            var blank = Random.int_range (0, width);

            for (var x = 0; x < width; x++)
            {
                if (y >= (height - filled_lines) && x != blank && Random.int_range (0, 10) < fill_prob)
                {
                    blocks[x, y] = new Block ();
                    blocks[x, y].x = x;
                    blocks[x, y].y = y;
                    blocks[x, y].color = Random.int_range (0, NCOLORS);
                }
                else
                    blocks[x, y] = null;
            }
        }

        if (!pick_difficult_blocks)
            next_shape = pick_random_shape ();
    }

    public Game copy ()
    {
        var g = new Game ();
        if (shape != null)
            g.shape = shape.copy ();
        if (next_shape != null)
            g.next_shape = next_shape.copy ();
        for (var x = 0; x < width; x++)
        {
            for (var y = 0; y < height; y++)
            {
                if (blocks[x, y] != null)
                    g.blocks[x, y] = blocks[x, y].copy ();
            }
        }
        g.n_lines_destroyed = n_lines_destroyed;
        g.score = score;
        g.difficulty = difficulty;
        g.pick_difficult_blocks = pick_difficult_blocks;
        g.fast_move_direction = fast_move_direction;
        g.fast_forward = fast_forward;
        g.has_started = has_started;
        g._paused = _paused;
        g.game_over = game_over;

        return g;
    }

    public void start ()
    {
        has_started = true;
        make_next_shape();
        add_shape ();
        setup_drop_timer ();
        started ();
        pause_changed ();
    }

    public bool move_left ()
    {
        return move_direction (-1);
    }

    public bool move_right ()
    {
        return move_direction (1);
    }

    public bool stop_moving ()
    {
        if (game_over)
            return false;

        if (fast_move_timeout != 0)
            Source.remove (fast_move_timeout);
        fast_move_timeout = 0;
        fast_move_direction = 0;

        return true;
    }

    public bool rotate_left ()
    {
        return try_rotate(1);
    }
    public bool rotate_right ()
    {
        return try_rotate(-1);
    }
    //will rotate the tetromino and if it doesn't fit, will try to move it a little horizontally so the rotation has the most chances of succeeding.
    //Example use case: The tetromino is on the left of right side of the grid, because it will probably not fit after rotation, we move it a little so it still gets rotated if there is enough space around the tetromino.
    private bool try_rotate (int r_step)
    {
        if (game_over)
            return false;

        int vmove = 0;
        if (shape.y < 0)
            vmove = 1;

        List<int> listHMoves = new List<int>();
        listHMoves.append(0);
        listHMoves.append(1);
        listHMoves.append(-1);
        listHMoves.append(2);
        listHMoves.append(-2);

        bool result = false;

        foreach (int hmove in listHMoves)
        {
            //tries to move the shape
            result = move_shape(hmove, vmove, r_step);
            //if rotation succeeded, we stop
            if (result) {
                break;
            }
        }

        //we return if any of our tries succeeded
        return result;
    }

    public bool get_fast_forward ()
    {
        return fast_forward;
    }

    public void set_fast_forward (bool enable)
    {
		//gamestate check
        if (fast_forward == enable || game_over)
            return;

		//we move the shape down a little, according to parameters
        if (enable)
            if (!move_shape (0, 1, 0))
                return;

        fast_forward = enable;
        setup_drop_timer ();
    }

    public void drop ()
    {
        if (shape == null)
            return;

        while (move_shape (0, 1, 0));
        fall_timeout_cb ();
    }

    public void stop ()
    {
        if (drop_timeout != 0)
            Source.remove (drop_timeout);
    }

    private bool move_direction (int direction)
    {
        if (game_over)
            return false;
        if (fast_move_direction == direction)
            return true;

        if (fast_move_timeout != 0)
            Source.remove (fast_move_timeout);
        fast_move_timeout = 0;
        fast_move_direction = direction;
        if (!move ())
            return false;

        fast_move_timeout = Timeout.add (AUTOMOVE_ACTIVATION_TIME, setup_fast_move_cb);

        return true;
    }

    // Following are the two callbacks who manages the auto moving of tetrominos. setup_fast_move_cb() and move().
    // Why two? As explained in a more detailled manner above the declaration of the constants AUTOMOVE_INTERVAL and AUTOMOVE_ACTIVATION_TIME,
    // the logic of auto moving is kinda separated in 2 phases : the "activating" and the "activated" phase, both of which have different delays.

    private bool setup_fast_move_cb ()
    {
        if (!move ())
        {
            //it should not stop trying to move the block until the player releases the left or right key. it could happens that on the edge of the screen
            //we rotate the block then it can move a little bit more.

            //return false;
        }
        fast_move_timeout = Timeout.add (AUTOMOVE_INTERVAL, move);

        return false;
    }

    private bool move ()
    {
        if (!move_shape (fast_move_direction, 0, 0))
        {
            //it should not stop trying to move the block until the player releases the left or right key. it could happens that on the edge of the screen
            //we rotate the block then it can move a little bit more.

            //fast_move_timeout = 0;
            //fast_move_direction = 0;
            //return false;
        }

        return true;
    }

    private void setup_drop_timer ()
    {
        var timestep = (int) Math.round (80 + 800.0 * Math.pow (0.75, level - 1));
        timestep = int.max (10, timestep);

        /* In fast forward mode drop at the fastest rate */
        if (fast_forward)
            timestep = 80;

        if (drop_timeout != 0)
            Source.remove (drop_timeout);
        drop_timeout = 0;
        if (!paused)
            drop_timeout = Timeout.add (timestep, fall_timeout_cb);
    }

    private bool fall_timeout_cb ()
    {
        /* Drop the shape down, and create a new one when it can't move */
        if (!move_shape (0, 1, 0))
        {
            /* Destroy any lines created */
            land_shape ();

            /* Add a new shape */
            add_shape ();
        }

        return true;
    }

    private void make_next_shape ()
    {
        if (pick_difficult_blocks)
        {
            next_shape = pick_difficult_shapes ();
        }
        else
        {
            next_shape = pick_random_shape ();
        }
    }

    private void add_shape ()
    {
        shape = (owned) next_shape;

        make_next_shape();

        foreach (var b in shape.blocks)
        {
            var x = shape.x + b.x;
            var y = shape.y + b.y;

            /* Abort if can't place there */
            if (y >= 0 && blocks[x, y] != null)
            {
                // FIXME: Place it where it can fit

                if (drop_timeout != 0)
                    Source.remove (drop_timeout);
                drop_timeout = 0;
                shape = null;
                game_over = true;
                complete ();
                return;
            }
        }

        shape_added ();
    }


    //array to keep track of the amount of each shape we have created. it's used for a better random shape distribution algorithm
    private int[] distshapecount = { 0, 0, 0, 0, 0, 0, 0 }; //there are 7 different shapes


    private Shape pick_random_shape ()
    {
        
        int shapecount = 7; //number of existing shapes, at least in distshapecount

        //find the smallest number in distshapecount
        int lowerbound = distshapecount[0]; //pick the first. maybe it already the smallest, but we will look for smaller ones
        for (int i = 0; i < shapecount; i++)
        {
            if (distshapecount[i] < lowerbound) {
                lowerbound = distshapecount[i];
            }
        }

        double sum = 0d;
        //we compute the sum of the weigh of each shape. the less the shape has been given to the player, the bigger the weigh
        for (int i = 0; i < shapecount; i++)
        {
            int rel = distshapecount[i] - lowerbound;
            //we have to make sure it's not 0
            if (rel < 1) { rel = 1; }

            double weigh = 1d / (double)(rel * rel);

            sum += weigh;
        }

        //we pick the random shape
        double rndshape = sum * Random.next_double ();

        //we figure out in which area the random number landed
        double currentpos = 0d; //our current position
        int newshape = 0; //increases by one every loop, until we find the area
        for (int i = 0; i < shapecount; i++)
        {
            int rel = distshapecount[i] - lowerbound;
            //we have to make sure it's not 0
            if (rel < 1) { rel = 1; }

            double weigh = 1d / (double)(rel * rel);

            currentpos += weigh;

            //if it's inside we break
            if (rndshape < currentpos) {
                break;
            }

            newshape++;
        }

        distshapecount[newshape]++;
        return make_shape (newshape, 0);
    }

    private Shape pick_difficult_shapes ()
    {
	/* The algorithm comes from Federico Poloni's "bastet" game */
        var metrics = new int[NCOLORS];
        for (var type = 0; type < NCOLORS; type++)
        {
            metrics[type] = -32000;
            for (var rotation = 0; rotation < 4; rotation++)
            {
                for (var pos = 0; pos < width; pos++)
                {
                    /* Copy the current game and create a block of the given type */
                    var g = copy ();
                    g.pick_difficult_blocks = false;
                    g.shape = make_shape (type, rotation);

                    /* Move tile to position from the left */
                    var valid_position = true;
                    while (g.move_shape (-1, 0, 0));
                    for (var x = 0; x < pos; x++)
                    {
                        if (!g.move_shape (1, 0, 0))
                        {
                            valid_position = false;
                            break;
                        }
                    }

                    if (!valid_position)
                        break;

                    /* Drop the tile here and check the metric */
                    var orig_lines = g.n_lines_destroyed;
                    g.drop ();

                    /* High metric for each line destroyed */
                    var metric = (g.n_lines_destroyed - orig_lines) * 5000;

                    /* Low metric for large columns */
                    for (var x = 0; x < width; x++)
                    {
                        int y;
                        for (y = 0; y < height; y++)
                        {
                            if (g.blocks[x, y] != null)
                                break;
                        }

                        metric -= 5 * (height - y);
                    }

                    if (metric > metrics[type])
                        metrics[type] = metric;

                    /* Destroy this copy */
                    g.stop ();
                }
            }
        }

        /* Perturb score (-2 to +2), to avoid stupid tie handling */
        for (var i = 0; i < NCOLORS; i++)
            metrics[i] += Random.int_range (-2, 2);

        /* Sorts possible_types by priorities, worst (interesting to us) first */
        var possible_types = new int[NCOLORS];
        for (var i = 0; i < NCOLORS; i++)
            possible_types[i] = i;
        for (var i = 0; i < NCOLORS; i++)
        {
            for (var j = 0; j < NCOLORS - 1; j++)
            {
                if (metrics[possible_types[j]] > metrics[possible_types[j + 1]])
                {
                    int t = possible_types[j];
                    possible_types[j] = possible_types[j + 1];
                    possible_types[j + 1] = t;
                }
            }
        }

        var new_shape = new Shape();
        /* Actually choose a piece */
        var rnd = Random.int_range (0, 99);
        if (rnd < 75)
            new_shape = make_shape (possible_types[0], Random.int_range (0, 4));
        else if (rnd < 92)
            new_shape = make_shape (possible_types[1], Random.int_range (0, 4));
        else if (rnd < 98)
            new_shape = make_shape (possible_types[2], Random.int_range (0, 4));
        else
            new_shape = make_shape (possible_types[3], Random.int_range (0, 4));

	    /* Look, this one is a great fit. It would be a shame if it wouldn't be given next */
	    //next_shape = make_shape (possible_types[NCOLORS - 1], Random.int_range (0, 4));

	    return new_shape;
    }

    private Shape make_shape (int type, int rotation)
    {
        var shape = new Shape ();
        shape.type = type;
        shape.rotation = rotation;

        /* Place this block at top of the field */
        var offset = shape.type * 64 + shape.rotation * 16;
        var min_width = 4, max_width = 0, min_height = 4, max_height = 0;
        for (var x = 0; x < 4; x++)
        {
            for (var y = 0; y < 4; y++)
            {
                if (block_table[offset + y * 4 + x] == 0)
                    continue;

                min_width = int.min (x, min_width);
                max_width = int.max (x + 1, max_width);
                min_height = int.min (y, min_height);
                max_height = int.max (y + 1, max_height);

                var b = new Block ();
                b.color = shape.type;
                b.x = x;
                b.y = y;
                shape.blocks.append (b);
            }
        }
        var block_width = max_width - min_width;
        shape.x = (width - block_width) / 2 - min_width;
        shape.y = -min_height;

        return shape;
    }

    private void land_shape ()
    {
        /* Leave these blocks here */
        foreach (var b in shape.blocks)
        {
            b.x += shape.x;
            b.y += shape.y;
            blocks[b.x, b.y] = b;
        }

        var fall_distance = 0;
        var lines = new int[4];
        var n_lines = 0;
        var base_line_destroyed = false;
        for (var y = height - 1; y >= 0; y--)
        {
            var explode = true;
            for (var x = 0; x < width; x++)
            {
                if (blocks[x, y] == null)
                {
                    explode = false;
                    break;
                }
            }

            if (explode)
            {
                if (y == height - 1)
                    base_line_destroyed = true;
                lines[n_lines] = y;
                n_lines++;
            }
        }
        lines.resize (n_lines);

        List<Block> line_blocks = null;
        for (var y = height - 1; y >= 0; y--)
        {
            var explode = true;
            for (var x = 0; x < width; x++)
            {
                if (blocks[x, y] == null)
                {
                    explode = false;
                    break;
                }
            }

            if (explode)
            {
                for (var x = 0; x < width; x++)
                {
                    line_blocks.append (blocks[x, y]);
                    blocks[x, y] = null;
                }
                fall_distance++;
            }
            else if (fall_distance > 0)
            {
                for (var x = 0; x < width; x++)
                {
                    var b = blocks[x, y];
                    if (b != null)
                    {
                        b.y += fall_distance;
                        blocks[b.x, b.y] = b;
                        blocks[x, y] = null;
                    }
                }
            }
        }

        var old_level = level;

        /* Score points */
        n_lines_destroyed += n_lines;
        switch (n_lines)
        {
        case 0:
            break;
        case 1:
            score += 40 * level;
            break;
        case 2:
            score += 100 * level;
            break;
        case 3:
            score += 300 * level;
            break;
        case 4:
            score += 1200 * level;
            break;
        }
        /* You get a bonus for getting back to the base */
        if (base_line_destroyed)
            score += 2500 * level * n_lines;

        /* Increase speed if level has changed */
        if (level != old_level)
            setup_drop_timer ();

        shape_landed (lines, line_blocks);
        shape = null;
    }

    private bool move_shape (int x_step, int y_step, int r_step)
    {
        if (shape == null)
            return false;

        /* Check it can fit into the new location */
        rotate_shape (r_step);
        var can_move = true;
        foreach (var b in shape.blocks)
        {
            var x = shape.x + x_step + b.x;
            var y = shape.y + y_step + b.y;
            if (x < 0 || x >= width || y >= height || (y >= 0 && blocks[x, y] != null))
            {
                can_move = false;
                break;
            }
        }

        /* Place in the new location or put it back where it was */
        if (can_move)
        {
            shape.x += x_step;
            shape.y += y_step;

            //Raises the appropriate signals. It is possible for multiple moves to be made at once, hence the reason why they are all separated. I have experienced refresh problems when not all concerned signals are called.
            if (x_step != 0)
                shape_moved ();

            if (y_step != 0)
                shape_dropped ();

            if (r_step != 0)
                shape_rotated ();
        }
        else
            rotate_shape (-r_step);

        return can_move;
    }

    private void rotate_shape (int r_step)
    {
        var r = shape.rotation + r_step;
        if (r < 0)
            r += 4;

        if (r >= 4)
            r -= 4;

        if (r == shape.rotation)
            return;
        shape.rotation = r;

        /* Rearrange current blocks */
        unowned List<Block> b = shape.blocks;
        var offset = shape.type * 64 + r * 16;
        for (var x = 0; x < 4; x++)
        {
            for (var y = 0; y < 4; y++)
            {
                if (block_table[offset + y * 4 + x] != 0)
                {
                    b.data.x = x;
                    b.data.y = y;
                    b = b.next;
                }
            }
        }
    }
}
