/*
 * This file is part of harbour-sudoku.
 *
 * harbour-sudoku is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * harbour-sudoku is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with harbour-sudoku.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.0
import Sailfish.Silica 1.0
import "../pages"

CoverBackground {
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Sudoku"
        }

        SudokuBoard {
            id: coverBoard
            anchors.horizontalCenter: parent.horizontalCenter
            cellSize: 20
            autoSetup: false
        }

        Timer {
            interval: 250
            running: true

            onTriggered: {
                coverBoard.setup();
            }
        }
    }
}
