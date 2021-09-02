classdef TicTacToe
	%TICTACTOE Simulation of Tic-Tac-Toe game
	%   This class simulates a Tic-Tac-Toe game as a 3x3 grid.
	%
	%	Players take turns to specify the row & column of the grid to insert
	%	their counter. Player 1 inserts +1, whereas player 2 inserts -1.
	%
	%	Play continues until a single player occupies all spaces in any one
	%	column, row or diagonal (i.e. player 1 wins if the sum of any column,
	%	row or diagonal equals 3, whereas player 2 wins if any such sums equal
	%	-3). If all spaces are occupied without a win, it is a draw.
	%
	%	This class also provides a basic AI who will choose where to insert the
	%	next counter
	
	properties%(SetAccess=private)
		Grid(3,3) {mustBeInteger, mustBeInRange(Grid, -1, 1)} = zeros(3);
		CurrentPlayer(1,1) {mustBeInteger, mustBeInRange(CurrentPlayer, 1, 2)} = 1;
		IllegalMove(1,1) logical;
	end
	
	methods
		
		%	====================================================================
		%	Object Constructor
		%	====================================================================
		function obj = TicTacToe
			obj = obj.Reset;
		end
		
		%	====================================================================
		%	Reset object
		%	====================================================================
		function obj = Reset(obj)
			obj.Grid = zeros(3);
			obj.CurrentPlayer = 1;
			obj.IllegalMove = false;
		end
		
		%	====================================================================
		%	Check for winner and winning column/row/diagonal
		%	====================================================================
		function [Winner, Result] = CheckWinner(obj)
			%	Check for draw
			if obj.NumberOfTurns == 9
				Winner = -1;
				Result = "Draw";
				return
			end
			
			%	Column of winning results
			P = ["Column " "Row "] + (1:3)';
			P = [P(:); "Diagnonal"; "Anti-Diagonal"];
			
			%	Get Scores
			S = obj.CalculateScores;
			
			%	Check for winning player
			if any(S==3)
				%	Player 1 won
				Winner = 1;
				Result = P(S==3);
			elseif any(S==-3)
				%	Player 2 won
				Winner = 2;
				Result = P(S==-3);
			else
				%	No winner
				Winner = 0;
				Result = [];
			end
		end
				
		%	====================================================================
		%	Insert counter into Row/Column
		%	====================================================================
		function obj = Insert(obj, Row, Col)
			arguments
				obj(1,1) TicTacToe
				Row(1,1) {mustBeInteger, mustBeInRange(Row, 1, 3)}
				Col(1,1) {mustBeInteger, mustBeInRange(Col, 1, 3)}
			end
			obj.IllegalMove = false;
			
			%	Check move is valid
			if ~obj.Grid(Row, Col)
				obj.Grid(Row, Col) = obj.GridValue;
				obj = obj.ChangePlayer;
			else
				obj.IllegalMove = true;
			end
		end
		
		%	====================================================================
		%	Choose locations
		%	====================================================================
		function obj = Choose(obj)
			%	Check for draw
			if obj.NumberOfTurns == 9
				return
			end
			
			%	Calculate scores & check for winner
			S = obj.CalculateScores;
			if any(abs(S)==3)
				return
			end
			
			%	Check for occupancy values
			N = obj.CalculateScores(true);
			val = obj.GridValue;
			
			%	Set sign of scores for current player to positive
			S = S.*sign(val);
			ind = [];
			count = 0;
			
			%	Function to determine optimal index
			FIND = @(n) find(S==n & N<3, 1, "first");
			
			%	Find optimum column/row/diag to insert next
			while isempty(ind)
				count = count + 1;
				switch count
					case 1
						%	Select winning position
						ind = FIND(2);
					case 2
						%	Block winning position
						ind = FIND(-2);
					case 3
						%	Create a winning position
						ind = FIND(1);
					case 4
						%	Choose centre or random
						ind = 9;
				end
			end
			
			%	Convert optimal index to grid position
			if ind<3
				C = ind;
				R = find(~obj.Grid(:, C), 1, "first");
			elseif ind>3 && ind<=6
				R = ind-3;
				C = find(~obj.Grid(R, :), 1, "first");
			elseif ind==7
				R = find(~diag(obj.Grid), 1, "first");
				C = R;
			elseif ind==8
				C = find(~diag(flip(obj.Grid)), 1, "first");
				R = 4 - C;
			else
				if ~obj.Grid(2,2)
					R = 2;
					C = 2;
				else
					ind = find(~obj.Grid);
					[R, C] = ind2sub([3 3], ind(randi(length(ind))));
				end
			end
			
			%	Insert counter
			obj = obj.Insert(R, C);
		end
	end
	
	methods (Access=private)
		%	====================================================================
		%	Calculate number of turns played
		%	====================================================================
		function N = NumberOfTurns(obj)
			N = sum(abs(obj.Grid), "all");
		end
		
		%	====================================================================
		%	Calculate the scores for each column, row & diagonal
		%	====================================================================
		function Scores = CalculateScores(obj, opt)
			G = obj.Grid;
			
			%	Calclulate occupancy instead of score
			if nargin>1 && opt
				G = abs(G);
			end
			%	Sum columns, then rows, then diagonals
			Scores = [sum(G) sum(G, 2).' trace(G) trace(flip(G))];
		end
		
		%	====================================================================
		%	Change current player
		%	====================================================================
		function obj = ChangePlayer(obj)
			%	Player 1 <--> Player 2
			obj.CurrentPlayer = 3 - obj.CurrentPlayer;
		end
		
		%	====================================================================
		%	Return the value to insert into grid
		%	====================================================================
		function val = GridValue(obj)
			%	Player 1 --> 1
			%	Player 2 --> -1
			val = 3 - 2*obj.CurrentPlayer;
		end
	end
end

