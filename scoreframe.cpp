/* -*- mode:C++; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */
/*
 * written by J. Marcin Gorycki <marcin.gorycki@intel.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * For more details see the file COPYING.
 */

#include <config.h>

#include <libgames-support/games-conf.h>
#include <libgames-support/games-frame.h>
#include <libgames-support/games-sound.h>

#include "scoreframe.h"
#include "tetris.h"

ScoreFrame::ScoreFrame(int cmdlLevel)
	: score(0), lines(0)
{
	if (cmdlLevel)
		startingLevel = cmdlLevel;
	else {
		startingLevel = games_conf_get_integer (KEY_OPTIONS_GROUP,
							KEY_STARTING_LEVEL,
							NULL);
	}
	startingLevel = CLAMP (startingLevel, 1, 20);

	level = startingLevel;

	w = gtk_table_new (3, 2, FALSE);

	scoreLabel = gtk_label_new (_("Score:"));
	gtk_misc_set_alignment (GTK_MISC (scoreLabel), 0.0, 0.5);
	gtk_table_attach_defaults (GTK_TABLE (w), scoreLabel,
				   0, 1, 0, 1);
	sprintf(b, "%7d", 0);
	scorew = gtk_label_new (b);
	gtk_misc_set_alignment (GTK_MISC (scorew), 1.0, 0.5);
	gtk_table_attach_defaults (GTK_TABLE (w), scorew,
				   1, 2, 0, 1);

	linesLabel = gtk_label_new (_("Lines:"));
	gtk_misc_set_alignment (GTK_MISC (linesLabel), 0.0, 0.5);
	gtk_table_attach_defaults (GTK_TABLE (w), linesLabel,
				   0, 1, 1, 2);
	sprintf(b, "%7d", 0);
	linesw = gtk_label_new (b);
	gtk_misc_set_alignment (GTK_MISC (linesw), 1.0, 0.5);
	gtk_table_attach_defaults (GTK_TABLE (w), linesw,
				   1, 2, 1, 2);


	levelLabel = gtk_label_new (_("Level:"));
	gtk_misc_set_alignment (GTK_MISC (levelLabel), 0.0, 0.5);
	gtk_table_attach_defaults (GTK_TABLE (w), levelLabel,
				   0, 1, 2, 3);
	sprintf(b, "%7d", level);
	levelw = gtk_label_new (b);
	gtk_misc_set_alignment (GTK_MISC (levelw), 1.0, 0.5);
	gtk_table_attach_defaults (GTK_TABLE (w), levelw,
				   1, 2, 2, 3);

}

void
ScoreFrame::show()
{
	gtk_widget_show_all (w);
}

void
ScoreFrame::setScore(int s)
{
	score = s;

	sprintf(b, "%7d", score);
	gtk_label_set_text(GTK_LABEL(scorew), b);
}

void
ScoreFrame::incScore(int s)
{
	setScore (score + s);
}

// The bonus for clearing everything.
void
ScoreFrame::scoreLastLineBonus ()
{
	incScore (10000*level);
	// FIXME: Get it its own sound?
	games_sound_play ("gnometris");
}

int
ScoreFrame::scoreLines(int newlines)
{
	int linescore = 0;

	switch(newlines)
	{
		case 0:
			return level;
		case 1:
			linescore = 40;
			games_sound_play ("lines1");
			break;
		case 2:
			linescore = 100;
			games_sound_play ("lines2");
			break;
		case 3:
			linescore = 300;
			games_sound_play ("lines3");
			break;
		case 4:
			linescore = 1200;
			games_sound_play ("lines3");
			break;
	}
	incScore (level*linescore);

	// check the level
	setLines (lines + newlines);
	int l = startingLevel + lines / 10;
	setLevel (l);

	return level;
}

void
ScoreFrame::setLevel(int l)
{
	level = l;
	sprintf(b, "%7d", level);
	gtk_label_set_text(GTK_LABEL(levelw), b);
}

void
ScoreFrame::setLines(int l)
{
	lines = l;
	sprintf(b, "%7d", lines);
	gtk_label_set_text(GTK_LABEL(linesw), b);
}

void
ScoreFrame::resetScore ()
{
	setLines (0);
	setScore (0);
}

void
ScoreFrame::setStartingLevel(int l)
{
	startingLevel = l;
}




