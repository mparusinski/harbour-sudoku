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
import QtQuick.LocalStorage 2.0
import Sailfish.Silica 1.0
import "."
import "Sudoku.js" as S

Grid {
    id: board
    rows: 3
    columns: 3
    spacing: 5

    property int cellSize
    property variant _currentSelection: null
    property int modelId: -1
    property bool resume: true
    property bool autoSetup: true

    property variant sudokuWorker: null

    function clearConflicts() {
        for(var block_no = 0; block_no < 9; block_no++) {
            blocks.itemAt(block_no).clearConflictMarks();
        }
    }

    function updateSelection(value) {
        if(_currentSelection) {
            var s = S.getSudoku(modelId);
            if(s.isInitialCell(_currentSelection.row, _currentSelection.column)) {
                return;
            }
            _currentSelection.value = value;

            s.set(_currentSelection.row, _currentSelection.column, value);
        }

        clearConflicts();

        if(isGameOver()) {
            pageStack.push(Qt.resolvedUrl('Victory.qml'), {
                board: this
            });
        }
    }

    Repeater {
        id: blocks
        model: 9

        SudokuBlock {
            cellSize: parent.cellSize
            blockNumber: index

            onCellSelected: {
                if(_currentSelection) {
                    _currentSelection.isHighlighted = false
                }
                _currentSelection = cell
                cell.isHighlighted = true;
            }
        }
    }

    function getBlockForCoords(row, col) {
        var blockNo  = Math.floor(col / 3) + (row - row % 3);
        var blockRow = row % 3;
        var blockCol = col % 3;

        return [
            blocks.itemAt(blockNo),
            blockRow,
            blockCol
        ];
    }

    function isGameOver() {
        var s = S.getSudoku(modelId);
        return s.isGameOver();
    }

    function showConflicts() {
        var s         = S.getSudoku(modelId);
        var conflicts = s.getConflicts();

        for(var i = 0; i < conflicts.length; i++) {
            var data = getBlockForCoords(conflicts[i].row, conflicts[i].col);

            var block = data[0];
            var bRow  = data[1];
            var bCol  = data[2];

            block.markAsConflict(bRow, bCol);
        }
    }

    function giveHint() {
        var s    = S.getSudoku(modelId);
        var hint = s.getHint();

        if(hint == null) {
            return;
        }

        var data = getBlockForCoords(hint.row, hint.col);

        var block = data[0];
        var bRow  = data[1];
        var bCol  = data[2];

        if(_currentSelection) {
            _currentSelection.isHighlighted = false;
        }
        _currentSelection = block.getCell(bRow, bCol);
        _currentSelection.isHighlighted = true;
        updateSelection(hint.value);
    }

    function openConnection() {
        var db = LocalStorage.openDatabaseSync('harbour-sudoku', '', 'Saved Game Data for Sudoku', 2000);

        if(db.version == '') {
            db.changeVersion('', '2.0', function(txn) {
                txn.executeSql('CREATE TABLE board (row INTEGER NOT NULL, column INTEGER NOT NULL, value INTEGER NOT NULL, is_initial INTEGER NOT NULL DEFAULT 0)');
            });
        } else if(db.version != '2.0') {
            db.changeVersion('1.0', '2.0', function(txn) {
                txn.executeSql('ALTER TABLE board ADD COLUMN is_initial INTEGER NOT NULL DEFAULT 0');
            });
        }

        return db;
    }

    function restore() {
        var db = openConnection();

        var rows = [];

        try {
            db.readTransaction(function(txn) {
                var result = txn.executeSql('SELECT row, column, value, is_initial FROM board');

                for(var i = 0; i < result.rows.length; i++) {
                    var row = result.rows.item(i);
                    rows.push({
                        row: row.row,
                        column: row.column,
                        value: row.value,
                        isInitial: row.is_initial
                    });
                }
            });
        } catch(e) {
            var code = e.code;

            if(code !== SQLException.DATABASE_ERR) {
                throw e;
            }
        }

        return rows.length == 0 ? null : rows;
    }

    function save() {
        var db = openConnection();
        var s  = S.getSudoku(modelId);

        db.transaction(function(txn) {
            txn.executeSql('DELETE FROM board');

            for(var row = 0; row < 9; row++) {
                for(var col = 0; col < 9; col++) {
                    var value     = s.get(row, col);
                    var isInitial = s.isInitialCell(row, col);

                    if(value != null) {
                        txn.executeSql('INSERT INTO board VALUES (?, ?, ?, ?)', [ row, col, value, isInitial ? 1 : 0 ]);
                    }
                }
            }
        });
    }

    function onBoardLoaded(state) {
        if(state.bg) {
            pageStack.pop(); // remove the Generating page
        }

        var rows = state.rows;
        modelId  = S.makeSudoku(rows);
        var s    = S.getSudoku(modelId);

        for(var row = 0; row < 9; row++) {
            for(var col = 0; col < 9; col++) {
                var value = s.get(row, col);

                var data  = getBlockForCoords(row, col);
                var block = data[0];
                var bRow  = data[1];
                var bCol  = data[2];

                block.set(bRow, bCol, value, s.isInitialCell(row, col));
            }
        }
    }

    function generateBoardInBackground(replace) {
        if(! sudokuWorker) {
            sudokuWorker = Qt.createQmlObject("import QtQuick 2.0; WorkerScript { source: 'Sudoku.js'; onMessage: onBoardLoaded(messageObject) }", board);
        }
        sudokuWorker.sendMessage();
        if(replace) {
            pageStack.replace(Qt.resolvedUrl('Generating.qml'), {}, PageStackAction.Immediate);
        } else {
            pageStack.push(Qt.resolvedUrl('Generating.qml'), {}, PageStackAction.Immediate);
        }
    }

    function reset() {
        generateBoardInBackground();
        clearConflicts();
    }

    function setup() {
        if(resume) {
            var rows = restore();
            if(rows !== null) {
                onBoardLoaded({
                    rows: rows,
                    bg:   false
                });
                return;
            }
        }

        generateBoardInBackground();
    }

    Component.onCompleted: {
        if(autoSetup) {
            setup();
        }
    }
}
