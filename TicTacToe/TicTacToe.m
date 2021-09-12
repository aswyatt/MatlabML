classdef TicTacToe < handle
	%TICTACTOE (handle) Simulation of Tic-Tac-Toe game
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
	
	properties (SetAccess=private)
		Grid(3,3) {mustBeInteger, mustBeInRange(Grid, -1, 1)} = zeros(3);
		CurrentPlayer(1,1) {mustBeInteger, mustBeInRange(CurrentPlayer, 1, 2)} = 1;
		IllegalMove(1,1) logical;
		
	end %	properties (SetAccess=private)
	
	methods
		
		%	====================================================================
		%	Object Constructor
		%	====================================================================
		function obj = TicTacToe
			obj.Reset;
		end %	function TicTacToe
		
		%	====================================================================
		%	Reset object
		%	====================================================================
		function Reset(obj)
			obj.Grid = zeros(3);
			obj.CurrentPlayer = 1;
			obj.IllegalMove = false;
		end %	function Reset
		
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
		end %	function CheckWinner
		
		%	====================================================================
		%	Insert counter into Row/Column
		%	====================================================================
		function Insert(obj, Row, Col)
			arguments
				obj(1,1) TicTacToe
				Row(1,1) {mustBeInteger, mustBeInRange(Row, 1, 3)}
				Col(1,1) {mustBeInteger, mustBeInRange(Col, 1, 3)}
			end
			obj.IllegalMove = false;
			
			%	Check move is valid
			if ~obj.Grid(Row, Col)
				obj.Grid(Row, Col) = obj.GridValue;
				obj.ChangePlayer;
			else
				obj.IllegalMove = true;
			end
		end %	function Insert
		
		%	====================================================================
		%	Choose location
		%	====================================================================
		function Choose(obj, Algorithm, varargin)
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
			
			switch Algorithm
				case "Bot"
					[R, C] = obj.BotAlgorithm(S, N, varargin{:});
				case "Agent"
					[R, C] = obj.AgentAlgorithm(varargin{1});
				otherwise
					[R, C] = obj.RandomAlgorithm;
			end
			
			%	Insert counter
			obj.Insert(R, C);
		end %	function Choose
		
		%	====================================================================
		%	Get State
		%	====================================================================
		function S = GetState(obj)
			S = sum(3.^(0:8).' .* mod(obj.Grid(:), 3)) + 1;
		end %	function GetState
		
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
		end %	function CalculateScores
		
		%	====================================================================
		%	Return the value to insert into grid
		%	====================================================================
		function val = GridValue(obj)
			%	Player 1 --> 1
			%	Player 2 --> -1
			val = 3 - 2*obj.CurrentPlayer;
		end %	function GridValue
		
		%	====================================================================
		%	Set the grid (need to validate)
		%	====================================================================
		function SetGrid(obj, G)
			obj.Grid = G;
			if sum(G==1, "all") == sum(G==-1, "all")
				obj.CurrentPlayer = 1;
			else
				obj.CurrentPlayer = 2;
			end
		end
	end %	methods
	
	methods (Access=private)
		
		%	====================================================================
		%	Change current player
		%	====================================================================
		function ChangePlayer(obj)
			%	Player 1 <--> Player 2
			obj.CurrentPlayer = 3 - obj.CurrentPlayer;
		end %	function ChangePlayer

		%	====================================================================
		%	Agent Algorithm
		%	====================================================================
		function [R, C] = AgentAlgorithm(obj, Agent)
			[R, C] = ind2sub([3 3], getAction(Agent, obj.GetState));
			if obj.Grid(R, C)
				[R, C] = obj.RandomAlgorithm;
			end
		end %	function AgentAlgorithm
		
		%	====================================================================
		%	Random Algorithm
		%	====================================================================
		function [R, C] = RandomAlgorithm(obj)
			ind = find(~obj.Grid(:));
			%	Account for quirk of randsample syntax
			if length(ind)>1
				ind = randsample(ind, 1);
			end
			[R, C] = ind2sub([3 3], ind);
		end %	function RandomAlgorithm
		
		%	====================================================================
		%	Bot Algorithm
		%	====================================================================
		function [R, C] = BotAlgorithm(obj, S, N, centre)
			%	Set sign of scores for current player to positive
			val = obj.GridValue;
			S = S.*sign(val);
			ind = [];
			count = 0;
			
			%	Function to determine optimal index
			FIND = @(n) find(S==n & N<3);
			
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
				end %	switch count ...
			end %	while ...
			
			if length(ind)>1
				ind = randsample(ind, 1);
			end
			
			R = [];
			C = [];
			%	Convert optimal index to grid position
			if ind<=3
				C = ind;
				R = find(~obj.Grid(:, C));
			elseif ind>3 && ind<=6
				R = ind-3;
				C = find(~obj.Grid(R, :));
			elseif ind==7
				R = find(~diag(obj.Grid));
				C = R;
			elseif ind==8
				C = find(~diag(flip(obj.Grid)));
				R = 4 - C;
			else
				if exist("centre", "var") && centre && ~obj.Grid(2,2)
					R = 2;
					C = 2;
				end
			end %	if ...
			
			if isempty(R) || isempty(C)
				[R, C] = obj.RandomAlgorithm;
			else
				if length(R)>1
					R = randsample(R, 1);
				end
				if length(C)>1
					C = randsample(C, 1);
				end
			end %	if			

		end %	function BotAlgorithm
	end %	 methods (Access=private)
end %	classdef

