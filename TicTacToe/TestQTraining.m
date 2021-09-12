clear;

%	Initialise script
Proj = currentProject;
cd(fullfile(Proj.RootFolder, "TicTacToe"));
rng(0);

%	Create environment
NumObs = 3^9;		%	Number of observation states (Pl 1, Pl 2 or empty in each grid position)
NumAct = 9;			%	Number of actions (3x3 grid)

%	Learning rate
NLR = 10;
LRmax = 1;
LR = (1:NLR).'*LRmax/NLR;

%	Epsilon
Neps = 20;
Epsmax = 1;
Epsilon = (1:Neps).'*Epsmax/Neps;

%	Decay Rate
NDR = 4;
DR = logspace(-NDR, -1, NDR);

OI = rlFiniteSetSpec(1:NumObs);		%	Observation Info
OI.Name = "Tic-Tac-Toe Observation States";

AI = rlFiniteSetSpec(1:NumAct);		%	Action Info
AI.Name = "Tic-Tac-Toe Actions";

env = rlFunctionEnv(OI, AI, @Step, @()Reset);

%	Create QTable
%		Note that not all states are possible (e.g. all one counter or some multiple
%		3 in a row)
qRepresentation = arrayfun(@(n) rlQValueRepresentation(...
	rlTable(OI, AI), OI, AI), LR);
for nLR=1:NLR
	qRepresentation(nLR).Options.LearnRate = LR(nLR);
end

%	Create Agent Options
qAgents = arrayfun(@(n) arrayfun(@(qRep) rlQAgent(qRep), qRepresentation), ...
	1:Neps*NDR, "UniformOutput", false);
qAgents = reshape(vertcat(qAgents{:}), NLR, Neps, NDR);
for nLR=1:NLR
	for neps=1:Neps
		for nDR = 1:NDR
			qAgents(nLR, neps, nDR).AgentOptions.EpsilonGreedyExploration.Epsilon ...
				= Epsilon(neps);
			qAgents(nLR, neps, nDR).AgentOptions.EpsilonGreedyExploration.EpsilonDecay ...
				= DR(nDR);
			qAgents(nLR, neps, nDR).AgentOptions.EpsilonGreedyExploration.EpsilonMin ...
				= eps(0);
		end
	end
end

%	Set training options
trainOpts = rlTrainingOptions;
trainOpts.MaxStepsPerEpisode = 10;
trainOpts.MaxEpisodes= 10;
trainOpts.StopTrainingCriteria = "EpisodeCount";
trainOpts.StopTrainingValue = trainOpts.MaxEpisodes;
trainOpts.ScoreAveragingWindowLength = 10;
trainOpts.Plots = "None";

%% Train the agent
multiWaitbar('Learning Rate', 'Reset', 'Color', 'g');
for nLR = 1:NLR
	multiWaitbar('Epsilon', 'Reset', 'Color', 'b');
	for neps = 1:Neps
		parfor nDR = 1:NDR
			trainingStats(nLR, neps, nDR) = train(qAgents(nLR, neps, nDR), ...
				env, trainOpts);
		end
		multiWaitbar('Epsilon', 'Increment', 1/Neps);
	end
	multiWaitbar('Learning Rate', 'Increment', 1/NLR);
end
multiWaitbar('CloseAll');

%% Compare the agents
Na = 1+numel(qAgents);
Ng = 10;
W = zeros(Na, Na, 3);

obj = TicTacToe;
%	Loop through player 1 agents
multiWaitbar('Player 1', 'Reset');
for na1=1:Na
	%	Select agent for player 1
	if na1<Na
		alg1 = "Agent";
		opt1 = qAgents(na1);
	else
		alg1 = "Bot";
		opt1 = true;
	end
	
	%	Loop through player 2 agents
	multiWaitbar('Player 2', 'Reset', 'Color', 'k');
	for na2=1:Na		
		%	Select agent for player 2
		if na2<Na
			alg2 = "Agent";
			opt2 = qAgents(na2);
		else
			alg2 = "Bot";
			opt2 = true;
		end
		
		%	Loop through games
		for ng=1:Ng
			w = 0;
			obj.Reset;
			while ~w
				obj.Choose(alg1, opt1);
				obj.Choose(alg2, opt2);
				w = obj.CheckWinner;
			end
			
			n = w + (w<0)*4;
			W(na1, na2, n) = W(na1, na2, n) + 1;
			if w<0
				D(na1, na2) = D(na1, na2) + 1;
			elseif w==1
				W1(na1, na2) = W1(na1, na2) + 1;
			else
				W2(na1, na2) = W2(na1, na2) + 1;
			end
		end
		multiWaitbar('Player 2', 'Increment', 1/Na);
	end
	multiWaitbar('Player 1', 'Increment', 1/Na);	
end
multiWaitbar('CloseAll');

imagesc(W1);
%% Reset function
% Used to generate initial state and logged signals (Data)
function [InitState, Data] = Reset(varargin)

Algorithms = ["Random", "Bot"];

Data = struct( ...
	"Obj", TicTacToe, ...
	"Player", randi(2), ...
	"Algorithm", randsample(Algorithms, 1, true, [1 10]), ...
	"Options", {{}});

switch Data.Algorithm
	case "Bot"
		Data.Options = {randsample([true false], 1, true, [4 1])};
end

if Data.Player==2
	Data.Obj.Choose(Data.Algorithm, Data.Options{:});
end

InitState = Data.Obj.GetState;
end


%% Step Function
% Used to generate the next step in the algorithm
% %	Step by applying the action to the game board
function [State, Reward, IsDone, Data] = Step(Action, Data)
Rewards = struct( ...
	"Step", -1, ...
	"Win", 100, ...
	"Draw", -5, ...
	"Lose", -100, ...
	"Illegal", -inf);

%	If currentplayer not changed, then return illegal move
if Data.Obj.Grid(Action)
	Result = nan;
else
	%	Attempt to insert counter in grid index Action
	[Row, Col] = ind2sub([3 3], Action);
	Data.Obj.Insert(Row, Col);
	Result = Data.Obj.CheckWinner;
	if abs(Result)~=1
		Data.Obj.Choose(Data.Algorithm, Data.Options{:});
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
end

