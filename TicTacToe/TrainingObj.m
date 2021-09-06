classdef TrainingObj < handle
	%TRAIN Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		Agents
		AgentIndex = 1;
		TrainingCount;
		NumAgents
		env
	end
	
	properties(Constant, Hidden)
		MaxPlayers = 2;
		NumRows = 3;
		NumColumns = 3;
		NumActions = TrainingObj.NumRows * TrainingObj.NumColumns;
		NumObservations = (TrainingObj.MaxPlayers+1).^TrainingObj.NumActions;
	end
	
	methods
		function obj = TrainingObj(Options)
			arguments
				Options.NumAgents(1,1) {mustBePositive, mustBeFinite, mustBeInteger} = 10;
				Options.LearnRate(1,1) {mustBePositive, mustBeFinite} = 1;
				Options.AgentOpts(1,1) rl.option.rlQAgentOptions = rlQAgentOptions;
			end			
			obj.InitializeQAgents(Options.NumAgents, Options.LearnRate, ...
				Options.AgentOpts);
		end
		
		function Train(obj, Iterations, Options)
			multiWaitbar('Iteration', 'Reset');
			for iter = 1:Iterations
				ind = randi(length(obj.Agents));
				obj.AgentIndex = ind;
				obj.TrainingCount(ind) = obj.TrainingCount(ind) + 1;
				train(obj.Agents(ind), obj.env, Options);
				multiWaitbar('Iteration', 'Increment', 1/Iterations);
			end
			multiWaitbar('Iteration', 'Close');
		end
	end %	methods
	
	methods(Access=private)
		function InitializeQAgents(obj, NumAgents, LearnRate, AgentOpts)
			%METHOD1 Summary of this method goes here
			%   Detailed explanation goes here
			
			%	Observation Info
			OI = rlFiniteSetSpec(1:obj.NumObservations);
			OI.Name = "Tic-Tac-Toe Observation States";
			
			%	Action Info
			AI = rlFiniteSetSpec(1:obj.NumActions);
			AI.Name = "Tic-Tac-Toe Actions";
			
			qTable = rlTable(OI, AI);
			qRepresentation = rlQValueRepresentation(qTable, OI, AI);
			qRepresentation.Options.LearnRate = LearnRate;
			
			obj.Agents = arrayfun(@(n) rlQAgent(qRepresentation, AgentOpts), ...
				1:NumAgents);
			obj.TrainingCount = zeros(length(obj.Agents), 1);
			obj.env = rlFunctionEnv(OI, AI, @(A, D)obj.Step(A, D), @()obj.Reset);
		end %	function InitializeQAgents
		
		function [InitState, Data] = Reset(obj)
			%	Select agent to play against
			N = length(obj.Agents);
			ind = find((1:N)~=obj.AgentIndex);
			W = 1./(1+obj.TrainingCount(ind));
			Agent = randsample(obj.Agents(ind), 1, true, W);
			Data = struct( ...
				"Obj", TicTacToe, ...
				"Player", randi(2), ...
				"Agent", Agent);
			
			%	If player 2, take first turn
			if Data.Player == 2
				Data.Obj.Choose("Agent", Data.Agent);
			end
			
			%	Calculate initial state
			InitState = Data.Obj.GetState;
		end %	function Reset
		
		function [State, Reward, IsDone, Data] = Step(obj, Action, Data)
			Rewards = struct( ...
				"Step", -1, ...
				"Win", 20, ...
				"Draw", -5, ...
				"Lose", -10, ...
				"Illegal", -inf);
			
			%	If currentplayer not changed, then return illegal move
			if Data.Obj.Grid(Action)
				Result = nan;
			else
				%	Attempt to insert counter in grid index Action
				[Row, Col] = ind2sub([obj.NumRows obj.NumColumns], Action);
				Data.Obj.Insert(Row, Col);
				Result = Data.Obj.CheckWinner;
				if abs(Result)~=1
					Data.Obj.Choose("Agent", Data.Agent);
					Result = Data.Obj.CheckWinner;
				end
			end
			
			switch Result
				case Data.Player
					Reward = Rewards.Win;
				case 3-Data.Player
					Reward = Rewards.Lose;
				case -1
					Reward = Rewards.Draw;
				case 0
					Reward = Rewards.Step;
				otherwise
					Reward = Rewards.Illegal;
			end
			if ~isfinite(Result) || logical(Result)
				IsDone = true;
			else
				IsDone = false;
			end
			
			State = Data.Obj.GetState;
		end %	function Step
	end %	methods
end %	classdef

