/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2014 Nikhar Agrawal
 *
 * This file is part of libgnome-games-support.
 *
 * libgnome-games-support is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * libgnome-games-support is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with libgnome-games-support.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Games {
namespace Scores {

private const string DIALOG_STYLE = """
dialog.scores columnview {
    background: transparent;
}

dialog.scores columnview header button,
dialog.scores columnview row cell {
    padding-left: 12px;
    padding-right: 12px;
}
""";

private class Dialog : Adw.Dialog
{
    private Context context;
    private Category? active_category = null;
    private List<Category?> categories = null;
    private ListStore? score_model = null;

    private Adw.ToolbarView toolbar;
    private Adw.HeaderBar headerbar;
    private Gtk.Button? new_game_button = null;
    private Gtk.DropDown? drop_down = null;
    private Gtk.ColumnView? score_view;
    private Gtk.ColumnViewColumn? rank_column;
    private Gtk.ColumnViewColumn? score_column;
    private Gtk.ColumnViewColumn? player_column;

    private Style scores_style;
    private Score? new_high_score;
    private string? score_or_time;

    public Dialog (Context context, string category_type, Style style, Score? new_high_score, Category? current_cat, string icon_name)
    {
        this.context = context;
        this.new_high_score = new_high_score;

        toolbar = new Adw.ToolbarView ();
        headerbar = new Adw.HeaderBar ();
        set_child (toolbar);
        toolbar.add_top_bar (headerbar);
        set_content_width (400);
        set_content_height (500);

        if (!context.has_scores () && new_high_score == null)
        {
            /* Empty State */
            set_title (_("No scores yet"));

            Adw.StatusPage status_page = new Adw.StatusPage ();
            toolbar.set_content (status_page);
            status_page.set_icon_name (icon_name + "-symbolic");
            status_page.set_description (_("Play some games and your scores will show up here."));
            status_page.add_css_class ("dim-label");

            return;
        }

        scores_style = style;
        categories = context.get_categories ();
        active_category = current_cat;

        add_css_class ("scores");

        if (active_category == null)
            active_category = new Category (categories.nth_data (0).key, categories.nth_data (0).name);
        
        score_or_time = "";
        string new_score_or_time = "";

        if (scores_style == Style.POINTS_GREATER_IS_BETTER || scores_style == Style.POINTS_LESS_IS_BETTER)
        {
            /* Translators: %1$s is the category type, %2$s is the category (e.g. "New Score for Level: 1") */
            new_score_or_time = _("New Score for %1$s: %2$s").printf (category_type, active_category.name);
            score_or_time = _("Score");
        }
        else
        {
            /* Translators: %1$s is the category type, %2$s is the category (e.g. "New Time for Level: 1") */
            new_score_or_time = _("New Time for %1$s: %2$s").printf (category_type, active_category.name);
            score_or_time = _("Time");
        }

        /* Decide what the title should be */
        categories = context.get_categories ();
        if (new_high_score != null)
        {
            var title_widget = new Adw.WindowTitle (_("Congratulations!"), new_score_or_time);
            headerbar.set_title_widget (title_widget);
        }
        else if (categories.length () == 1)
        {
            active_category = ((!) categories.first ()).data;
            set_title (active_category.name);
        }
        else
        {
            drop_down = new Gtk.DropDown.from_strings (load_categories ());
            var list_factory = drop_down.get_factory ();
            var button_factory = new Gtk.SignalListItemFactory ();

            button_factory.setup.connect ((factory, object) => {
                unowned var list_item = object as Gtk.ListItem;

                list_item.child = new Gtk.Label (null) {
                    ellipsize = Pango.EllipsizeMode.END,
                    xalign = 0
                };
            });
            button_factory.bind.connect ((factory, object) => {
                unowned var list_item = object as Gtk.ListItem;
                unowned var string_object = list_item.item as Gtk.StringObject;
                unowned var label = list_item.child as Gtk.Label;

                /* Translators: %1$s is the category type, %2$s is the category (e.g. "Level: 1") */
                label.label = _("%1$s: %2$s").printf (category_type, string_object.@string);
            });

            drop_down.set_factory (button_factory);
            drop_down.set_list_factory (list_factory);

            drop_down.notify["selected"].connect(() => {
                var selected_index = drop_down.get_selected();
                if (selected_index != -1)
                    load_scores_for_category (categories.nth_data (selected_index));
            });
            for (int i = 0; i != categories.length (); i++)
            {
                var category = categories.nth_data (i);
                if (category == active_category)
                    drop_down.set_selected (i);
            }

            unowned var popover = drop_down.get_last_child () as Gtk.Popover;
            popover.halign = Gtk.Align.CENTER;

            headerbar.set_title_widget (drop_down);
        }

        /* Add the data to the dialog */
        var scroll = new Gtk.ScrolledWindow ();
        score_view = new Gtk.ColumnView (null);
        score_view.set_reorderable (false);
        score_view.set_tab_behavior (ITEM);
        setup_columns ();
        load_scores_for_category (active_category);
        scroll.set_child (score_view);
        toolbar.set_content (scroll);
        this.focus_widget = score_view;
    }

    /* load names of all categories into a string array */
    private string[] load_categories ()
    {
        string[] categories_array = {};

        categories.foreach ((x) => categories_array += x.name);

        return categories_array;
    }

    /*
     * Most of the code below is from gnome-mahjongg
     * Copyright 2010-2013 Robert Ancell
     * Copyright 2010-2025 Mahjongg Contributors
     */

    private void load_scores_for_category (Category category)
    {
        score_model.remove_all ();
        var best_n_scores = context.get_high_scores (category, 10);
        foreach (var score in best_n_scores)
            score_model.append (score);

        score_view.scroll_to (0, null, Gtk.ListScrollFlags.NONE, null);
        active_category = category;
    }

    private void setup_columns ()
    {
        set_up_rank_column ();
        set_up_score_column ();
        set_up_player_column ();
        score_view.append_column (rank_column);
        score_view.append_column (score_column);
        score_view.append_column (player_column);
        score_column.set_expand (true);
        score_column.set_fixed_width (0);
        player_column.set_expand (true);
        player_column.set_fixed_width (0);

        score_model = new ListStore (typeof (Score));
        var sort_model = new Gtk.SortListModel (score_model, score_view.sorter);
        score_view.model = new Gtk.NoSelection (sort_model);
        score_view.sort_by_column (rank_column, Gtk.SortType.ASCENDING);

        score_view.sorter.changed.connect (() => {
            /* Scroll to top when resorting */
            score_view.scroll_to (0, null, Gtk.ListScrollFlags.FOCUS, null);
        });

        if (new_high_score == null)
            return;

        var controller = new Gtk.EventControllerFocus ();
        controller.enter.connect (() => {
            Idle.add (() => {
                score_view.scroll_to (new_high_score.rank - 1, null, Gtk.ListScrollFlags.FOCUS, null);
                score_view.child_focus (Gtk.DirectionType.TAB_FORWARD);  // Focus the text entry
                return false;
            });
        });
        score_view.add_controller (controller);
    }

    private void set_up_rank_column () {
        var factory = new Gtk.SignalListItemFactory ();
        var sorter = new Gtk.MultiSorter ();

        factory.setup.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            var label = new Gtk.Inscription (null);
            label.add_css_class ("caption");
            label.add_css_class ("numeric");
            list_item.child = label;
        });
        factory.bind.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            unowned var label = list_item.child as Gtk.Inscription;
            unowned var score = list_item.item as Score;

            label.text = score.rank.to_string ();
        });

        if (scores_style == Style.POINTS_GREATER_IS_BETTER || scores_style == Style.TIME_GREATER_IS_BETTER)
            sorter.append (new Gtk.CustomSorter ((CompareDataFunc<Score>) Score.score_greater_sorter));
        else
            sorter.append (new Gtk.CustomSorter ((CompareDataFunc<Score>) Score.score_less_sorter));

        rank_column = new Gtk.ColumnViewColumn ("Rank", factory);
        rank_column.sorter = sorter;
    }

    private void set_up_score_column () {
        var factory = new Gtk.SignalListItemFactory ();

        factory.setup.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            var label = new Gtk.Inscription (null);
            label.add_css_class ("numeric");

            list_item.child = label;
        });
        if (scores_style == Style.POINTS_GREATER_IS_BETTER || scores_style == Style.POINTS_LESS_IS_BETTER)
        {
            factory.bind.connect ((factory, object) => {
                unowned var list_item = object as Gtk.ListItem;
                unowned var label = list_item.child as Gtk.Inscription;
                unowned var score = list_item.item as Score;

                label.text = score.score.to_string ();
            });
        }
        else
        {
            factory.bind.connect ((factory, object) => {
                unowned var list_item = object as Gtk.ListItem;
                unowned var label = list_item.child as Gtk.Inscription;
                unowned var score = list_item.item as Score;

                if (score.score >= 60)
                    label.text = "%ldm %lds".printf (score.score / 60, score.score % 60);
                else
                    label.text = "%lds".printf (score.score);
            });
        }

        score_column = new Gtk.ColumnViewColumn (score_or_time, factory);
        score_column.sorter = rank_column.sorter;
    }

    private void set_up_player_column () {
        var factory = new Gtk.SignalListItemFactory ();

        factory.bind.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            unowned var score = list_item.item as Score;

            if (score == new_high_score)
            {
                var entry = new Gtk.Entry ();
                entry.text = score.user;
                entry.set_has_frame (false);
                entry.add_css_class ("heading");
                entry.notify["text"].connect (() => {
                    context.update_score_name (score, active_category, entry.get_text ());
                    score.user = entry.get_text ();
                });
                entry.activate.connect (() => {
                    if (new_game_button != null)
                        new_game_button.activate ();
                    else
                        this.close ();
                });

                list_item.child = entry;
            }
            else
            {
                list_item.child = new Gtk.Inscription (score.user);
            }
        });

        player_column = new Gtk.ColumnViewColumn (_("Player"), factory);
    }

    internal void add_bottom_buttons (Context.NewGameFunc new_game_func, Context.QuitAppFunc quit_app_func)
    {
        headerbar.set_show_end_title_buttons (true);
        new_game_button = new Gtk.Button.with_label (_("_New Game")) {
            can_shrink = true,
            use_underline = true
        };
        new_game_button.clicked.connect (() => {
            this.close ();
            new_game_func ();
        });

        Adw.ButtonContent quit_button_content = new Adw.ButtonContent () {
            icon_name = "application-exit-symbolic",
            label = _("_Quit"),
            use_underline = true,
            can_shrink = true
        };
        Gtk.Button quit_button = new Gtk.Button () {
            child = quit_button_content,
            can_shrink = true,
            valign = Gtk.Align.CENTER
        };
        quit_button.clicked.connect (() => {
            this.close ();
            quit_app_func ();
        });

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        var bottom_bar = new Gtk.CenterBox () {
            hexpand = true,
            center_widget = new_game_button,
            end_widget = quit_button
        };
        box.append (bottom_bar);

        new_game_button.add_css_class ("pill");
        new_game_button.add_css_class ("suggested-action");
        box.add_css_class ("toolbar");
        bottom_bar.add_css_class ("toolbar");
        toolbar.add_bottom_bar (box);
    }
}

} /* namespace Scores */
} /* namespace Games */
