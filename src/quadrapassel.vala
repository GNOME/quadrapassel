/* quadrapassel.vala
 *
 * Copyright 2010-2013 Robert Ancell
 * Copyright 2025-2026 Will Warner
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

public class Quadrapassel : Adw.Application
{
    /* Application settings */
    private Settings settings;

    /* Main window */
    private Adw.ApplicationWindow window;
    private Adw.HeaderBar headerbar;
    private Gtk.EventControllerKey event_controller_key;
    private Gtk.GestureSwipe swipe_gesture;
    private Gtk.GestureLongPress long_press_gesture;
    private Gtk.MenuButton menu_button;

    /* Game scores */
    private Games.Scores.Context context;

    /* GridFrame for the game */
    private Games.GridFrame game_aspect;

    /* Game being played */
    private Game? game = null;

    /* Rendering of game */
    private GameView view;

    /* The box that holds the game view and stats box */
    private Gtk.Box game_box;

    /* The box that holds the stats */
    private Gtk.Box stats_box;

    /* Preview of the next shape */
    private Preview preview;
    private Games.GridFrame preview_frame;
    string next_string = _("Next");
    string hold_string = _("Hold");
    private Gtk.Label preview_label;

    /* Label showing current score */
    private Gtk.Label score_label;

    /* Label showing the number of lines destroyed */
    private Gtk.Label n_destroyed_label;

    /* Label showing the current level */
    private Gtk.Label level_label;

    private SimpleAction pause_action;

    private Gtk.Button pause_play_button;
    private Gtk.Button new_game_button;

    private Manette.Monitor manette_monitor;
    private const uint16[] MANETTE_BUTTONS = {
        InputEventCode.BTN_A,
        InputEventCode.BTN_B,
        InputEventCode.BTN_X,
        InputEventCode.BTN_Y,
        InputEventCode.BTN_TL,
        InputEventCode.BTN_TR,
        InputEventCode.BTN_TL2,
        InputEventCode.BTN_TR2,
        InputEventCode.BTN_SELECT,
        InputEventCode.BTN_START,
        InputEventCode.BTN_MODE,
        InputEventCode.BTN_THUMBL,
        InputEventCode.BTN_THUMBR,
        InputEventCode.BTN_DPAD_UP,
        InputEventCode.BTN_DPAD_DOWN,
        InputEventCode.BTN_DPAD_LEFT,
        InputEventCode.BTN_DPAD_RIGHT,
    };
    private HashTable<uint16, bool> buttons_state = new HashTable<uint16, bool> (direct_hash, direct_equal);

    private const uint[] KEYS = {
        Gdk.Key.Return,
        Gdk.Key.Pause,
        Gdk.Key.w,
        Gdk.Key.a,
        Gdk.Key.s,
        Gdk.Key.d,
        Gdk.Key.q,
        Gdk.Key.e,
        Gdk.Key.h,
        Gdk.Key.p,
        Gdk.Key.space,
        Gdk.Key.Up,
        Gdk.Key.Down,
        Gdk.Key.Left,
        Gdk.Key.Right,
    };

    private bool pause_requested = false;

    /* Keyboard Keys */
    private HashTable<uint, bool> keys_state = new HashTable<uint16, bool> (direct_hash, direct_equal);

    private const GLib.ActionEntry[] ACTION_ENTRIES =
    {
        { "new-game", new_game_cb },
        { "pause", pause_cb },
        { "scores", scores_cb },
        { "menu", menu_cb },
        { "theme", theme_cb },
        { "preferences", preferences_cb },
        { "rules", rules_cb },
        { "about", about_cb },
        { "quit", quit_cb }
    };

    public Quadrapassel ()
    {
        Object (application_id: APP_ID, flags: ApplicationFlags.DEFAULT_FLAGS, resource_base_path: "/org/gnome/Quadrapassel");
    }

    protected override void startup ()
    {
        base.startup ();

        Adw.StyleManager.get_default ().set_color_scheme (FORCE_DARK);

        Environment.set_application_name (_("Quadrapassel"));

        add_action_entries (ACTION_ENTRIES, this);
        set_accels_for_action ("app.new-game", {"<Primary>n"});
        set_accels_for_action ("app.menu", {"F10"});
        set_accels_for_action ("app.rules", {"F1"});
        set_accels_for_action ("app.preferences", {"<Primary>comma"});
        set_accels_for_action ("app.quit", {"<Primary>q"});
        set_accels_for_action ("window.close", {"<Primary>w"});
        pause_action = lookup_action ("pause") as SimpleAction;

        settings = new Settings (APP_ID);
    }

    private void create_window ()
    {
        var builder = new Gtk.Builder ();
        window = new Adw.ApplicationWindow (this);
        window.set_size_request (360, 330);
        window.icon_name = APP_ID;
        window.title = _("Quadrapassel");

        var breakpoint = new Adw.Breakpoint (new Adw.BreakpointCondition.length (MAX_WIDTH, 400, PX));
        window.add_child (builder, breakpoint, null);

        event_controller_key = new Gtk.EventControllerKey ();
        event_controller_key.key_pressed.connect (key_press_event_cb);
        event_controller_key.key_released.connect (key_release_event_cb);
        ((Gtk.Widget) window).add_controller (event_controller_key);

        swipe_gesture = new Gtk.GestureSwipe ();
        swipe_gesture.swipe.connect (swipe_cb);
        long_press_gesture = new Gtk.GestureLongPress ();
        long_press_gesture.pressed.connect (long_press_cb);

        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        window.notify["is-active"].connect (on_window_focus_change);

        var toolbar_view = new Adw.ToolbarView ();
        headerbar = new Adw.HeaderBar ();
        toolbar_view.add_child (builder, headerbar, "top");
        window.set_content (toolbar_view);

        new_game_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic");
        new_game_button.set_action_name ("app.new-game");
        new_game_button.set_tooltip_text (_("Start a new game"));

        headerbar.pack_start (new_game_button);

        var menu = new Menu ();
        var section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Scores"), "app.scores");
        section.append (_("App_earance"), "app.theme");
        section.append (_("_Preferences"), "app.preferences");
        section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Keyboard Shortcuts"), "app.shortcuts");
        section.append (_("Game _Rules"), "app.rules");
        section.append (_("_About Quadrapassel"), "app.about");
        menu_button = new Gtk.MenuButton ();
        menu_button.primary = true;
        menu_button.tooltip_text = _("Main Menu");
        menu_button.set_icon_name ("open-menu-symbolic");
        menu_button.set_menu_model (menu);

        var toggle_button = menu_button.get_first_child ();
        bool popover_shown = false;

        window.notify["focus-widget"].connect (() => {
            // Un-focus the Main Menu if it is not in use
            if (window.focus_widget == toggle_button &&
                !menu_button.popover.visible &&
                popover_shown == true)
            {
                game_aspect.grab_focus ();
                popover_shown = false;
            }
            on_window_focus_change ();
        });

        menu_button.popover.show.connect (() => popover_shown = true);

        headerbar.pack_end (menu_button);

        game_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        game_box.margin_start = 12;
        game_box.margin_end = 12;
        game_box.margin_bottom = 12;
        toolbar_view.set_content (game_box);
        breakpoint.apply.connect (breakpoint_apply_cb);
        breakpoint.unapply.connect (breakpoint_unapply_cb);

        view = new GameView ();
        view.theme = settings.get_string ("theme");
        view.mute = !settings.get_boolean ("sound");
        view.show_shadow = settings.get_boolean ("show-shadow");
        view.game = new Game (20, 10, 1, 20, 10); // Game board size, changed width to 10
        game_aspect = new Games.GridFrame (10, 20);
        game_aspect.hexpand = true;
        game_aspect.vexpand = true;
        game_aspect.child = view;
        game_aspect.add_controller (swipe_gesture);
        game_aspect.add_controller (long_press_gesture);
        game_aspect.receives_default = true;
        game_aspect.focusable = true;
        game_aspect.accessible_role = Gtk.AccessibleRole.LABEL;
        game_aspect.update_property (Gtk.AccessibleProperty.LABEL, _("Game View"), -1);
        game_box.append (game_aspect);

        pause_play_button = new Gtk.Button ();
        pause_play_button.set_icon_name ("media-playback-start-symbolic");
        pause_play_button.action_name = "app.new-game";
        pause_play_button.tooltip_text = _("Start a new game");
        pause_play_button.set_receives_default (false);
        headerbar.pack_end (pause_play_button);

        stats_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        game_box.append (stats_box);

        var preview_card = new AdaptiveCard (next_string, "");
        preview_label = preview_card.info_type;
        preview_card.info.visible = false;

        preview_frame = new Games.GridFrame (5, 5);
        preview_frame.vexpand = true;
        preview = new Preview ();
        preview.theme = settings.get_string ("theme");
        preview.enabled = settings.get_boolean ("do-preview");
        preview_frame.child = preview;

        preview_card.box.append (preview_frame);
        stats_box.append (preview_card);

        var score_card = new AdaptiveCard (_("Score"), "0");
        score_label = score_card.info;
        score_label.width_request = 100;
        stats_box.append (score_card);

        var destroyed_card = new AdaptiveCard (_("Rows"), "0");
        n_destroyed_label = destroyed_card.info;
        stats_box.append (destroyed_card);

        var level_card = new AdaptiveCard (_("Level"), "0");
        level_label = level_card.info;
        stats_box.append (level_card);

        context = new Games.Scores.Context ("quadrapassel",
                                            /* Label on the scores dialog */
                                            _("Difficulty"),
                                            create_category_from_key,
                                            Games.Scores.Style.POINTS_GREATER_IS_BETTER,
                                            APP_ID,
                                            -1,
                                            new Games.Scores.HistoryFileImporter (parse_old_score));

        foreach (unowned var button in MANETTE_BUTTONS)
            buttons_state[button] = false;

        manette_monitor = new Manette.Monitor ();
        manette_monitor.device_connected.connect (manette_device_connected_cb);
        var manette_iterator = manette_monitor.iterate ();
        Manette.Device manette_device = null;
        while (manette_iterator.next (out manette_device))
            manette_device_connected_cb (manette_device);

        foreach (unowned var key in KEYS)
            keys_state[key] = false;

        pause_action.set_enabled (false);
        new_game_button.set_sensitive (false);
    }

    protected override void shutdown ()
    {
        /* Record the score if the game isn't over. */
        if (game != null && !game.game_over && game.score > 0)
        {
            var category_key = game.difficulty.to_string ();
            if (game.pick_difficult_blocks)
                category_key = category_key + "-difficult";

            context.add_score_full.begin (game.score, create_category_from_key (category_key), get_game_extra_info (), null, false, null, (object, result) => {
                try
                {
                    context.add_score_full.end (result);
                }
                catch (Error e)
                {
                    warning ("%s", e.message);
                }
            });
        }

        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window.get_width ());
        int width, height;
        window.get_default_size (out width, out height);

        settings.set_int ("window-width", width);
        settings.set_int ("window-height", height);
        settings.set_boolean ("window-is-maximized", window.maximized);
    }

    protected override void activate ()
    {
        if (window == null)
            create_window ();

        window.present ();
    }

    private void breakpoint_apply_cb () {
        score_label.width_request = -1;
        game_box.remove (stats_box);
        game_box.orientation = Gtk.Orientation.VERTICAL;
        game_box.prepend (stats_box);
        stats_box.orientation = Gtk.Orientation.HORIZONTAL;

        AdaptiveCard card = (AdaptiveCard) stats_box.get_first_child ();
        stats_box.remove (card);
        stats_box.append (card);
        card.orientation = Gtk.Orientation.HORIZONTAL;
        card.box.get_first_child ().margin_end = 4;
        card = (AdaptiveCard) stats_box.get_first_child ();

        for (uint i = 0; i < 3; i++)
        {
            card.orientation = Gtk.Orientation.HORIZONTAL;

            card = (AdaptiveCard) card.get_next_sibling ();
        }
    }

    private void breakpoint_unapply_cb () {
        score_label.width_request = 100;
        game_box.remove (stats_box);
        game_box.orientation = Gtk.Orientation.HORIZONTAL;
        game_box.append (stats_box);
        stats_box.orientation = Gtk.Orientation.VERTICAL;

        AdaptiveCard card = (AdaptiveCard) stats_box.get_last_child ();
        stats_box.remove (card);
        stats_box.prepend (card);
        card.orientation = Gtk.Orientation.VERTICAL;
        card.box.get_first_child ().margin_end = 0;
        card = (AdaptiveCard) card.get_next_sibling ();

        for (uint i = 0; i < 3; i++)
        {
            card.orientation = Gtk.Orientation.VERTICAL;

            card = (AdaptiveCard) card.get_next_sibling ();
        }
    }

    private void on_window_focus_change ()
    {
        if (game != null && !game.game_over)
        {
            if (game_aspect.has_focus && window.is_active)
            {
                if (!pause_requested)
                    game.paused = false;
            }
            else
            {
                if (!pause_play_button.has_focus && !new_game_button.has_focus)
                {
                    foreach (unowned var key in KEYS)
                        if (keys_state[key])
                            key_release_event_cb (event_controller_key, key, 0, Gdk.ModifierType.NO_MODIFIER_MASK);

                    game.paused = true;
                }
            }
        }
    }

    /* NOTE: This is a fragile system, only this and
     * on_window_focus_change () should change pause state */
    private void user_pause ()
    {
        game.paused = !game.paused;
        pause_requested = game.paused;
    }

    private void preferences_cb ()
    {
        var preferences_dialog = new Adw.PreferencesDialog ();
        preferences_dialog.set_title (_("Preferences"));

        var game_page = new Adw.PreferencesPage ();
        game_page.set_title (_("Game"));

        var difficulty_group = new Adw.PreferencesGroup ();
        difficulty_group.set_title (_("Game Difficulty"));
        difficulty_group.set_description (_("Change how difficult the game is"));
        var more_info = new MoreInfoButton ();
        more_info.text = _("The Difficulty affects the level you start at and how many rows are pre-filled.");
        difficulty_group.set_header_suffix (more_info);

        /* difficulty */
        // the maximum should be at least 4 less than the new game height but as long as the game height is a magic 20 and not a setting, we can keep it at 15
        var adj = new Gtk.Adjustment (settings.get_int ("difficulty"), -1, 15, 1, 5, 0);
        var difficulty_row = new Adw.SpinRow (adj, 10, 0);
        difficulty_row.set_title (_("_Difficulty"));
        difficulty_row.set_use_underline (true);
        difficulty_row.set_update_policy (Gtk.SpinButtonUpdatePolicy.ALWAYS);
        difficulty_row.set_snap_to_ticks (true);
        difficulty_row.changed.connect (() => settings.set_int ("difficulty", (int) difficulty_row.get_value ()));
        difficulty_group.add (difficulty_row);

        var difficult_blocks_toggle = new Adw.SwitchRow ();
        difficult_blocks_toggle.set_title (_("Choose difficult _blocks"));
        difficult_blocks_toggle.set_use_underline (true);
        difficult_blocks_toggle.set_active (settings.get_boolean ("pick-difficult-blocks"));
        difficult_blocks_toggle.notify["active"].connect (() => settings.set_boolean ("pick-difficult-blocks", difficult_blocks_toggle.get_active ()));
        difficulty_group.add (difficult_blocks_toggle);

        game_page.add (difficulty_group);

        var in_game_group = new Adw.PreferencesGroup ();
        in_game_group.set_title (_("In-Game"));
        in_game_group.set_description (_("Change the experience of playing a game"));

        var sound_toggle = new Adw.SwitchRow ();
        sound_toggle.set_title (_("_Enable sounds"));
        sound_toggle.set_use_underline (true);
        sound_toggle.set_active (settings.get_boolean ("sound"));
        sound_toggle.notify["active"].connect (() => {
            var play_sound = sound_toggle.get_active ();
            settings.set_boolean ("sound", play_sound);
            view.mute = !play_sound;
        });
        in_game_group.add (sound_toggle);

        var do_preview_toggle = new Adw.SwitchRow ();
        do_preview_toggle.set_title (_("_Preview next block"));
        do_preview_toggle.set_use_underline (true);
        do_preview_toggle.set_active (settings.get_boolean ("do-preview"));
        do_preview_toggle.notify["active"].connect (() => {
            var preview_enabled = do_preview_toggle.get_active ();
            settings.set_boolean ("do-preview", preview_enabled);
            preview.enabled = preview_enabled;
        });
        in_game_group.add (do_preview_toggle);

        /* rotate counter clock wise */
        var rotate_counter_clock_wise_toggle = new Adw.SwitchRow ();
        rotate_counter_clock_wise_toggle.set_title (_("_Rotate blocks counterclockwise"));
        rotate_counter_clock_wise_toggle.set_use_underline (true);
        rotate_counter_clock_wise_toggle.set_active (settings.get_boolean ("rotate-counter-clock-wise"));
        rotate_counter_clock_wise_toggle.notify["active"].connect (() => settings.set_boolean ("rotate-counter-clock-wise", rotate_counter_clock_wise_toggle.get_active ()));
        in_game_group.add (rotate_counter_clock_wise_toggle);

        var show_shadow_toggle = new Adw.SwitchRow ();
        show_shadow_toggle.set_title (_("Show _where the block will land"));
        show_shadow_toggle.set_use_underline (true);
        show_shadow_toggle.set_active (settings.get_boolean ("show-shadow"));
        show_shadow_toggle.notify["active"].connect (() => {
            var show_shadow = show_shadow_toggle.get_active ();
            settings.set_boolean ("show-shadow", show_shadow);
            view.show_shadow = show_shadow;
        });
        in_game_group.add (show_shadow_toggle);

        var game_seed = new Adw.EntryRow ();
        game_seed.set_title (_("Game _seed"));
        game_seed.set_use_underline (true);
        game_seed.set_text (settings.get_uint ("seed").to_string ());
        game_seed.set_sensitive (settings.get_boolean ("use-seed"));
        game_seed.changed.connect (() => { settings.set_uint ("seed", uint.parse (game_seed.get_text ())); });
        more_info = new MoreInfoButton ();
        more_info.text = _("The seed is used to determine which blocks you get. While a seed is set, the game will be the same every time.");
        game_seed.add_suffix (more_info);

        var use_seed_toggle = new Adw.SwitchRow ();
        use_seed_toggle.set_title (_("_Use a custom seed for the game"));
        use_seed_toggle.set_use_underline (true);
        use_seed_toggle.set_active (settings.get_boolean ("use-seed"));
        use_seed_toggle.notify["active"].connect (() => {
            bool active = use_seed_toggle.get_active ();
            settings.set_boolean ("use-seed", active);
            game_seed.set_sensitive (active);
        });

        in_game_group.add (use_seed_toggle);
        in_game_group.add (game_seed);

        game_page.add (in_game_group);
        preferences_dialog.add (game_page);
        preferences_dialog.present (window);
    }

    private Gtk.Widget theme_update (string theme_name, Gtk.Widget theme_preview_widget)
    {
        var theme_preview_frame = theme_preview_widget as Games.GridFrame;
        var theme_preview = theme_preview_frame.child as Preview;
        view.theme = theme_name;
        preview.theme = theme_name;
        theme_preview.theme = theme_name;
        settings.set_string ("theme", theme_name);
        return theme_preview_widget;
    }

    private void theme_cb ()
    {
        var theme_preview_frame = new Games.GridFrame (5, 5);
        theme_preview_frame.hexpand = true;
        theme_preview_frame.vexpand = true;
        theme_preview_frame.set_size_request (150, 150);
        theme_preview_frame.margin_top = 12;
        theme_preview_frame.margin_bottom = 12;
        var theme_preview = new Preview ();
        theme_preview.theme = settings.get_string ("theme");
        theme_preview.update_block (new Game ().next_shape);
        theme_preview_frame.child = theme_preview;
        var dialog = new Games.ThemeSelectorDialog ({"plain", "clean", "modern"},
                                                    settings.get_string ("theme"),
                                                    theme_preview_frame);
        dialog.change_theme.connect (theme_update);
        dialog.present (window);
    }

    private void pause_cb ()
    {
        if (game != null)
            user_pause ();
    }

    private void quit_cb ()
    {
        if (window != null)
            window.close ();

        base.quit ();
    }

    private void manette_device_connected_cb (Manette.Device manette_device)
    {
        manette_device.button_press_event.connect (manette_button_press_event_cb);
        manette_device.button_release_event.connect (manette_button_release_event_cb);
        manette_device.absolute_axis_event.connect (manette_absolute_axis_event_cb);
    }

    private void manette_button_press_event_cb (Manette.Event event)
    {
        uint16 button;
        if (!event.get_button (out button))
            return;

        if (buttons_state[button])
            return;

        buttons_state[button] = true;

        if (button == InputEventCode.BTN_SELECT)
        {
            if (game_aspect.has_focus)
                new_game ();

            return;
        }

        if (button == InputEventCode.BTN_START)
        {
            if (!game_aspect.has_focus)
                return;

            if (game == null)
                new_game ();
            else if (!game.game_over)
                user_pause ();
            else
                new_game ();

            return;
        }

        if (game == null)
            return;

        if (game.paused)
            return;

        if (button == InputEventCode.BTN_DPAD_LEFT)
        {
            game.move_left ();
            return;
        }
        else if (button == InputEventCode.BTN_DPAD_RIGHT)
        {
            game.move_right ();
            return;
        }
        else if (button == InputEventCode.BTN_TL2 || button == InputEventCode.BTN_TL)
        {
            game.rotate_left ();
            return;
        }
        else if (button == InputEventCode.BTN_TR2 || button == InputEventCode.BTN_TR)
        {
            game.rotate_right ();
            return;
        }
        else if (button == InputEventCode.BTN_B || button == InputEventCode.BTN_A)
        {
            game.set_fast_forward (true);
            return;
        }
        else if (button == InputEventCode.BTN_X)
        {
            game.hold ();
            return;
        }
        else if (button == InputEventCode.BTN_DPAD_DOWN)
        {
            game.drop ();
            return;
        }
        else if (button == InputEventCode.BTN_DPAD_UP)
        {
            if (settings.get_boolean ("rotate-counter-clock-wise"))
                game.rotate_left ();
            else
                game.rotate_right ();
        }
    }

    private void manette_button_release_event_cb (Manette.Event event)
    {
        uint16 button;
        if (!event.get_button (out button))
            return;

        if (!buttons_state[button])
            return;

        buttons_state[button] = false;

        if (game == null)
            return;

        if (button == InputEventCode.BTN_DPAD_LEFT ||
            button == InputEventCode.BTN_DPAD_RIGHT)
        {
            game.stop_moving ();
            return;
        }
        else if (button == InputEventCode.BTN_B || button == InputEventCode.BTN_A)
        {
            game.set_fast_forward (false);
            return;
        }
    }

    private void manette_absolute_axis_event_cb (Manette.Event event)
    {
        if (game == null || game.paused)
            return;

        uint16 axis;
        double val;
        event.get_absolute (out axis, out val);

        if (axis != InputEventCode.ABS_X)
            return;

        var abs = val.abs ();
        if (abs < 0.5)
        {
            game.stop_moving ();
            return;
        }

        if (val > 0)
            game.move_right ();
        else if (val < 0)
            game.move_left ();
    }

    private bool key_press_event_cb (Gtk.EventControllerKey controller,
                                     uint keyval,
                                     uint keycode,
                                     Gdk.ModifierType state)
    {
        if (game != null)
        {
            if (game.game_over && keyval == Gdk.Key.Return)
            {
                new_game ();
                return true;
            }
        }
        else
        {
            if (keyval == Gdk.Key.Return)
            {
                new_game ();
                return true;
            }

            return false;
        }

        if (keyval == Gdk.Key.Pause || keyval == Gdk.Key.p)
        {
            if (!game.game_over)
                user_pause ();
            return true;
        }

        if (game.paused)
            return false;

        if (keys_state[keyval])
            return true;

        keys_state[keyval] = true;

        if (keyval == Gdk.Key.Left || keyval == Gdk.Key.a)
        {
            game.move_left ();
            return true;
        }
        else if (keyval == Gdk.Key.Right || keyval == Gdk.Key.d)
        {
            game.move_right ();
            return true;
        }
        else if (keyval == Gdk.Key.Up || keyval == Gdk.Key.w)
        {
            if (settings.get_boolean ("rotate-counter-clock-wise"))
                game.rotate_left ();
            else
                game.rotate_right ();

            return true;
        }
        else if (keyval == Gdk.Key.Down || keyval == Gdk.Key.s)
        {
            game.set_fast_forward (true);
            return true;
        }
        else if (keyval == Gdk.Key.q)
        {
            game.rotate_left ();
            return true;
        }
        else if (keyval == Gdk.Key.e)
        {
            game.rotate_right ();
            return true;
        }
        else if (keyval == Gdk.Key.space)
        {
            game.drop ();
            return true;
        }
        else if (keyval == Gdk.Key.h)
        {
            game.hold ();
            return true;
        }

        return false;
    }

    private void key_release_event_cb (Gtk.EventControllerKey controller,
                                       uint keyval,
                                       uint keycode,
                                       Gdk.ModifierType state)
    {
        if (game == null)
            return;

        if (!keys_state[keyval])
            return;

        keys_state[keyval] = false;

        if (keyval == Gdk.Key.Left || keyval == Gdk.Key.a)
        {
            game.stop_moving ();
            if (keys_state[Gdk.Key.Right] || keys_state[Gdk.Key.d])
                game.move_right ();

            return;
        }
        else if (keyval == Gdk.Key.Right || keyval == Gdk.Key.d)
        {
            game.stop_moving ();
            if (keys_state[Gdk.Key.Left] || keys_state[Gdk.Key.a])
                game.move_left ();

            return;
        }
        else if (keyval == Gdk.Key.Down ||
                 keyval == Gdk.Key.s)
        {
            game.set_fast_forward (false);
            return;
        }
    }

    private void swipe_cb (double velocity_x, double velocity_y)
    {
        if (game == null || game.paused)
            return;

        /* For some reason tapping/clicking is treated as a swipe, but with 0 velocity.
         * Annoyingly, the release of a long press is treated as a swipe too,
         * so it is necessary to check for this. At the same time there is the feature
         * of clicking/tapping to rotate the blocks, which makes the game a lot easier
         * on mobile devices.
         */
        if (velocity_x == 0 && velocity_y == 0)
        {
            if (game.get_fast_forward ())
                {
                    game.set_fast_forward (false);
                }
            else
            {
                if (settings.get_boolean ("rotate-counter-clock-wise"))
                    game.rotate_left ();
                else
                    game.rotate_right ();
            }

            return;
        }

        double direction = (Math.atan2 (velocity_y, velocity_x) * 180) / Math.PI;
        if (direction < 0)
            direction += 360.0;

        if (direction >= 135 && direction < 225)
        {
            game.move_left ();
            game.stop_moving ();
        }

        else if (direction >= 315 || direction < 45)
        {
            game.move_right ();
            game.stop_moving ();
        }
        else if (direction >= 225 && direction < 315)
        /* Swiping up is an alternative to clicking/tapping,
         * so we use it to give the user the option of rotating blocks
         * in the opposite direction of what they set in the preferences
         */
        {
            if (settings.get_boolean ("rotate-counter-clock-wise"))
                game.rotate_right ();
            else
                game.rotate_left ();
        }
        else
            game.drop ();
    }

    private void long_press_cb (double x, double y)
    {
        if (game != null)
            game.set_fast_forward (true);
    }

    private void new_game_cb ()
    {
        new_game ();
    }

    private void new_game ()
    {
        if (game != null)
        {
            game.stop ();
            SignalHandler.disconnect_matched (game, SignalMatchType.DATA, 0, 0, null, null, this);
        }

        pause_requested = false;

        if (settings.get_boolean ("use-seed"))
            Random.set_seed (settings.get_uint ("seed"));

        int pre_filled = settings.get_int ("difficulty");

        if (pre_filled < 0)
            pre_filled = 0;

        // Set game dimension, change to 10
        game = new Game (20,
                         10,
                         settings.get_int ("difficulty") /* The starting level */,
                         pre_filled,
                         5 /* line fill density  */,
                         settings.get_boolean ("pick-difficult-blocks"));

        game.pause_changed.connect (pause_changed_cb);
        game.shape_landed.connect (shape_landed_cb);
        game.shape_added.connect (shape_added_cb);
        game.shape_held.connect (shape_held_cb);
        game.complete.connect (complete_cb);
        game_aspect.grab_focus ();
        view.game = game;

        game.start ();

        update_score ();
        pause_action.set_enabled (true);
        new_game_button.set_sensitive (true);
        pause_play_button.action_name = "app.pause";
    }

    private void pause_changed_cb ()
    {
        if (game.paused)
        {
            pause_play_button.set_icon_name ("media-playback-start-symbolic");
            pause_play_button.tooltip_text = _("Unpause the game");
            preview.set_hidden (true);
        }
        else
        {
            pause_play_button.set_icon_name ("media-playback-pause-symbolic");
            pause_play_button.tooltip_text = _("Pause the game");
            preview.set_hidden (false);

            // Focus the game aspect again
            game_aspect.grab_focus ();
        }
    }

    private void shape_landed_cb (int[] lines, List<Block> line_blocks)
    {
        update_score ();
    }

    private void shape_added_cb ()
    {
        if (game.shape == null || game.held_shape != null)
            return;

        preview_label.label = next_string;
        preview.update_block (game.next_shape);
    }

    private void shape_held_cb ()
    {
        if (game.held_shape == null)
            return;

        preview_label.label = hold_string;
        preview.update_block (game.held_shape);
    }

    private string get_game_extra_info ()
    {
        return "%s: %i\n%s: %i\n".printf (_("Rows"), game.n_lines_destroyed, _("Level"), game.level);
    }

    private void complete_cb ()
    {
        pause_action.set_enabled (false);
        pause_play_button.set_icon_name ("media-playback-start-symbolic");
        pause_play_button.action_name = "app.new-game";
        pause_play_button.tooltip_text = _("Start the game");
        new_game_button.set_sensitive (false);

        if (game.score > 0)
        {
            var category_key = game.difficulty.to_string ();
            if (game.pick_difficult_blocks)
                category_key = category_key + "-difficult";

            context.add_score_full.begin (game.score, create_category_from_key (category_key), get_game_extra_info (), window, true, null, (object, result) => {
                try
                {
                    var score_result = context.add_score_full.end (result).action;
                    if (score_result == Games.Scores.AddScoreAction.NEW_GAME)
                        new_game ();
                    else if (score_result == Games.Scores.AddScoreAction.QUIT)
                        quit_cb ();
                }
                catch (Error e)
                {
                    warning ("%s", e.message);
                }
            });
        }
    }

    private Games.Scores.Category create_category_from_key (string key)
    {
        if (key == "old-scores") {
            return new Games.Scores.Category (key, _("Old Scores"));
        }

        int index = key.last_index_of_char ('-');

        if (index > 0)
        {
            string level = key.substring (0, index);
            return new Games.Scores.Category (key, level + "-" + _("Difficult"));
        }

        /* For the scores dialog. Just the difficulty level (a number). */
        return new Games.Scores.Category (key, key);
    }

    private int64 parse_date (string date)
    {
        if (date.length < 19 || date[4] != '-' || date[7] != '-' || date[10] != 'T' || date[13] != ':' || date[16] != ':')
            warning ("Failed to parse date: %s", date);

        var year = int.parse (date.substring (0, 4));
        var month = int.parse (date.substring (5, 2));
        var day = int.parse (date.substring (8, 2));
        var hour = int.parse (date.substring (11, 2));
        var minute = int.parse (date.substring (14, 2));
        var seconds = int.parse (date.substring (17, 2));
        try {
            var timezone = new GLib.TimeZone.identifier (date.substring (19));
            return new DateTime (timezone, year, month, day, hour, minute, seconds).to_unix ();
        } catch (GLib.Error e) {
            warning ("Failed to parse date: %s", date);
            return 0;
        }
    }

    private void parse_old_score (string line, out Games.Scores.Score score, out Games.Scores.Category category)
    {
        score = null;
        category = null;

        var tokens = line.split (" ");
        if (tokens.length != 2)
            return;

        var date = parse_date (tokens[0]);
        var points = int.parse (tokens[1]);

        if (date <= 0 || points < 0)
            return;

        score = new Games.Scores.Score (points, date);
        category = create_category_from_key ("old-scores");
    }

    private void update_score ()
    {
        var score = 0;
        var level = 0;
        var n_lines_destroyed = 0;

        if (game != null)
        {
            score = game.score;
            level = game.level;
            n_lines_destroyed = game.n_lines_destroyed;
        }

        score_label.set_markup (score.to_string ());
        level_label.set_markup (level.to_string ());
        n_destroyed_label.set_markup (n_lines_destroyed.to_string ());
    }

    private void rules_cb ()
    {
        var dialog_builder = new Gtk.Builder ();
        try
        {
            dialog_builder.add_from_resource ("/org/gnome/Quadrapassel/rules-dialog.ui");
        }
        catch (Error e)
        {
            critical ("Could not load rules dialog: %s", e.message);
        }
        var rules_dialog = (Adw.Dialog) dialog_builder.get_object ("rules_dialog");
        var game_symbolic = (Gtk.Image) dialog_builder.get_object ("game_symbolic");
        var points_row = (Adw.ActionRow) dialog_builder.get_object ("points_row");
        var points_info = (Gtk.Grid) dialog_builder.get_object ("points_info");
        var more_info = new MoreInfoButton ();
        more_info.text = C_("game rules", "Points are calculated based on how many rows are destroyed.");
        more_info.extra_child = points_info;
        points_row.add_suffix (more_info);
        game_symbolic.set_from_icon_name ("%s-symbolic".printf (APP_ID));
        rules_dialog.present (window);
    }

    private void about_cb ()
    {
        string[] authors =
        {
            "J. Marcin Gorycki",
            "Lubomir Rintel",
            "Robert Ancell",
            "John Ward",
            "Will Warner",
        };

        var about = new Adw.AboutDialog () {
            application_name = _("Quadrapassel"),
            application_icon = APP_ID,
            developers = authors,
            issue_url = "https://gitlab.gnome.org/GNOME/quadrapassel/-/issues",
            comments = _("A classic game where you rotate blocks to make complete rows, but don't pile your blocks too high or it's game over!"),
            copyright = "Copyright © 1999 J. Marcin Gorycki, 2000–2015 Others",
            license_type = Gtk.License.GPL_3_0,
            translator_credits = _("translator-credits"),
            version = VERSION,
            website = "https://wiki.gnome.org/Apps/Quadrapassel",
        };

        about.present (this.active_window);
    }

    private void menu_cb ()
    {
        menu_button.activate ();
    }

    private void scores_cb ()
    {
        var category_key = settings.get_int ("difficulty").to_string ();
        if (settings.get_boolean ("pick-difficult-blocks"))
            category_key = category_key + "-difficult";

        context.present_dialog (window, create_category_from_key (category_key));
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        var app = new Quadrapassel ();
        return app.run (args);
    }
}
