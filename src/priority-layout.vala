/* priority-layout.vala
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

public class PriorityLayout : Gtk.LayoutManager, Gtk.Orientable {
    public int min_spacing = 0;
    public int max_spacing_add = 0;
    public Gtk.Orientation orientation { get; set; }
    private Gtk.Widget priority;

    public PriorityLayout (int min_spacing, int max_spacing, Gtk.Widget priority)
    {
        this.min_spacing = min_spacing;
        this.max_spacing_add = max_spacing - min_spacing;
        this.priority = priority;
    }

    public override void allocate (Gtk.Widget widget, int width, int height, int baseline)
    {
        int fill; /* Widgets get the full amount */
        int divvy; /* Split among widgets */

        if (orientation == Gtk.Orientation.VERTICAL)
        {
            fill = width;
            divvy = height;
        }
        else
        {
            fill = height;
            divvy = width;
        }

        int n_children = 0;
        int children_min = 0;
        int children_nat = 0;
        int priority_nat = 0;
        int priority_min = 0;

        /* Gather overall size information */
        for (Gtk.Widget child = widget.get_first_child (); child != null; child = child.get_next_sibling ())
        {
            int minimum, natural;

            child.measure (orientation, fill, out minimum, out natural, null, null);

            children_min += minimum;
            children_nat += natural;

            if (child == priority)
            {
                priority_nat = natural;
                priority_min = minimum;
            }

            n_children += 1;
        }

        if (n_children == 0)
            return;

        divvy -= (n_children - 1) * min_spacing; /* Don't give spacing pixels to widgets */

        if (children_min >= divvy)
        { /* Give the widgets their minimums */
            int offset = 0;

            for (Gtk.Widget child = widget.get_first_child (); child != null; child = child.get_next_sibling ())
            {
                int minimum;
                Gtk.Allocation allocation;

                child.measure (orientation, fill, out minimum, null, null, null);

                if (orientation == Gtk.Orientation.VERTICAL)
                {
                    allocation = Gtk.Allocation () {
                        x = 0,
                        y = offset,
                        height = minimum,
                        width = width,
                    };
                }
                else
                {
                    allocation = Gtk.Allocation () {
                        x = offset,
                        y = 0,
                        height = height,
                        width = minimum,
                    };
                }

                child.allocate_size (allocation, -1);

                offset += (minimum + min_spacing);
            }
        }
        else if (children_nat > divvy)
        { /* Give the priority widget as much of its natural size as possible, other widgets get the rest */
            int offset = 0;
            int unprioritized_min = children_min - priority_min;
            int priority_size = int.min (divvy - unprioritized_min, priority_nat);
            int extra = ((divvy - priority_size) - unprioritized_min) / (n_children - 1);

            for (Gtk.Widget child = widget.get_first_child (); child != null; child = child.get_next_sibling ())
            {
                int size;
                Gtk.Allocation allocation;

                if (child == priority)
                    size = priority_size;
                else
                {
                    int minimum;
                    child.measure (orientation, fill, out minimum, null, null, null);
                    size = minimum + extra;
                }

                if (orientation == Gtk.Orientation.VERTICAL)
                {
                    allocation = Gtk.Allocation () {
                        x = 0,
                        y = offset,
                        height = size,
                        width = width,
                    };
                }
                else
                {
                    allocation = Gtk.Allocation () {
                        x = offset,
                        y = 0,
                        height = height,
                        width = size,
                    };
                }

                child.allocate_size (allocation, -1);

                offset += (size + min_spacing);
            }
        }
        else
        { /* Give all of the widgets their natural size, center them, and add some spacing  */
            int offset;
            int extra = (divvy - children_nat);
            int extra_spacing = int.min (max_spacing_add, extra / 3);
            offset = (extra - extra_spacing) / 2;

            for (Gtk.Widget child = widget.get_first_child (); child != null; child = child.get_next_sibling ())
            {
                int natural;
                Gtk.Allocation allocation;

                child.measure (orientation, fill, null, out natural, null, null);

                if (orientation == Gtk.Orientation.VERTICAL)
                {
                    allocation = Gtk.Allocation () {
                        x = 0,
                        y = offset,
                        height = natural,
                        width = width,
                    };
                }
                else
                {
                    allocation = Gtk.Allocation () {
                        x = offset,
                        y = 0,
                        height = height,
                        width = natural,
                    };
                }

                child.allocate_size (allocation, -1);

                offset += (natural + min_spacing + extra_spacing);
            }
        }
    }

    public override void measure (Gtk.Widget widget,
                                  Gtk.Orientation orientation,
                                  int for_size,
                                  out int children_min,
                                  out int children_nat,
                                  out int minimum_baseline,
                                  out int natural_baseline)
    {
        if (orientation == this.orientation)
        {
            int n_children = 0;
            children_min = 0;
            children_nat = 0;

            for (Gtk.Widget child = widget.get_first_child (); child != null; child = child.get_next_sibling ())
            {
                int minimum, natural;

                child.measure (orientation, for_size, out minimum, out natural, null, null);

                children_min += minimum;
                children_nat += natural;
                n_children += 1;
            }

            minimum_baseline = natural_baseline = -1;
            children_min += min_spacing;
            children_nat += min_spacing;
        }
        else
        {
            children_min = 0;
            children_nat = 0;

            for (Gtk.Widget child = widget.get_first_child (); child != null; child = child.get_next_sibling ())
            {
                int minimum, natural;

                child.measure (orientation, for_size, out minimum, out natural, null, null);

                children_min = int.max (minimum, children_min);
                children_nat = int.max (natural, children_nat);
            }

            minimum_baseline = natural_baseline = -1;
        }

        if (children_nat < children_min)
            children_nat = children_min;
    }
}
