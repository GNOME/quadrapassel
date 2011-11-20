/* -*- mode:C++; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */
#ifndef __scoreframe_h__
#define __scoreframe_h__

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

class ScoreFrame {
public:
	ScoreFrame (int cmdlLevel);

	void show ();
	void resetScore ();
	void setLevel (int l);
	void setStartingLevel (int l);

	int getScore () {
		return score;
	}
	int getLines () {
		return lines;
	}
	int getLevel () {
		return level;
	}

	GtkWidget *getWidget () {
		return w;
	}

	int scoreLines (int nlines);
	void scoreLastLineBonus ();

private:
	GtkWidget * w;
	GtkWidget *scorew;
	GtkWidget *linesw;
	GtkWidget *levelw;
	GtkWidget *scoreLabel;
	GtkWidget *linesLabel;
	GtkWidget *levelLabel;
	GtkWidget *hbScore;
	GtkWidget *hbLines;
	GtkWidget *hbLevel;
	GtkWidget *vb;
	char b[20];

	int level;
	int score;
	int lines;
	int startingLevel;

	void setScore (int score);
	void setLines (int lines);
	void incScore (int score);
};

#endif //__scoreframe_h__
