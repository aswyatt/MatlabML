clear;

%	Initialise script
Proj = currentProject;
cd(fullfile(Proj.RootFolder, "TicTacToe"));
rng(0);

PARAM = struct( ...
	"Var", "Decay Rate", ...
	"LR", .3, ...
	"Epsilon", .3, ...
	"DR", 1e-3);
% PARAM = "Epsilon";
% PARAM = "Decay Rate";

%	Create environment
NumObs = 3^9;		%	Number of observation states (Pl 1, Pl 2 or empty in each grid position)
NumAct = 9;			%	Number of actions (3x3 grid)

%	Learning rate
NLR = 10;
LRmax = 1;
LR = (1:NLR).'*LRmax/NLR;

%	Epsilon
% Epsmax = .5;
% Epsmin = .08;
% Epsilon = (Epsmin:.02:Epsmax).';
% Epsilon = linspace(Epsmin, Epsmax, Neps);
% Neps = length(Epsilon);
Neps = 10;
Epsmax = 1;
Epsilon = (1:Neps).'*Epsmax/Neps;

%	Decay Rate
NDR = 5;
DR = logspace(-NDR, -1, NDR);

switch PARAM.Var
	case "Learning Rate"
		N = NLR;
	case "Epsilon"
		N = Neps;
	case "Decay Rate"
		N = NDR;
end

OI = rlFiniteSetSpec(1:NumObs);		%	Observation Info
OI.Name = "Tic-Tac-Toe Observation States";

AI = rlFiniteSetSpec(1:NumAct);		%	Action Info
AI.Name = "Tic-Tac-Toe Actions";

env = rlFunctionEnv(OI, AI, @Step, @()Reset);

%	Create QTable
%		Note that not all states are possible (e.g. all one counter or some multiple
%		3 in a row)

qRepr = rlQValueRepresentation(rlTable(OI, AI), OI, AI);
if strcmp(PARAM.Var, "Learning Rate")
	qRepr = repmat(qRepr, [NLR 1]);
	for nLR=1:NLR
		qRepr(nLR).Options.LearnRate = LR(nLR);
	end
else
	qRepr.Options.LearnRate = PARAM.LR;
end

%	Create Agent Options
AO = rlQAgentOptions;
AO.EpsilonGreedyExploration.Epsilon = PARAM.Epsilon;
AO.EpsilonGreedyExploration.EpsilonDecay = PARAM.DR;
AO.EpsilonGreedyExploration.EpsilonMin = eps(0);
if any(strcmp(PARAM.Var, ["Epsilon" "Decay Rate"]))
	qAgents = arrayfun(@(n) rlQAgent(qRepr, AO), (1:N).');
	
	if strcmp(PARAM.Var, "Epsilon")
		for n=1:N
			qAgents(n).AgentOptions.EpsilonGreedyExploration.Epsilon ...
				= Epsilon(n);
		end
	else
		for n=1:N
			qAgents(n).AgentOptions.EpsilonGreedyExploration.EpsilonDecay ...
				= DR(n);
		end
	end
else
	qAgents = arrayfun(@(qRepr) rlQAgent(qRepr, AO), qRepr);
end

%	Set training options
trainOpts = rlTrainingOptions;
trainOpts.MaxStepsPerEpisode = 10;
trainOpts.MaxEpisodes= 10000;
trainOpts.StopTrainingCriteria = "EpisodeCount";
trainOpts.StopTrainingValue = trainOpts.MaxEpisodes;
trainOpts.ScoreAveragingWindowLength = 10;
trainOpts.Plots = "None";

%% Train the agent
parfor n=1:N
	trainingStats(n) = train(qAgents(n), env, trainOpts);
end

%% Compare the agents
Na = 1+numel(qAgents);
Ng = 100;
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
		end
		multiWaitbar('Player 2', 'Increment', 1/Na);
	end
	multiWaitbar('Player 1', 'Increment', 1/Na);
end
multiWaitbar('CloseAll');

W1 = sum(W(:, :, 2)).' *100/(Na*Ng);
W2 = sum(W(:, :, 1), 2) * 100/(Na*Ng);

%%
clf;
tiledlayout("flow", "TileSpacing", "loose", "Padding", "compact");
colormap(jet);
CLIM = [floor(min(W, [], "all")) ceil(max(W, [], "all"))];
for n=1:3
	ax = nexttile;
	bar3(W(:, :, n))
% 	imagesc(W(:, :, n), "Parent", ax);
% 	set(gca, "CLim", CLIM);
	if n<3
		title("Winner = Plyr " + n);
	else
		title("Draw");
	end
	xlabel("Player 2");
	ylabel("Player 1");
end
h = colorbar("Location", "eastoutside");
h.Label.String = "Frequency [%]";

nexttile;
h = bar([W1 W2], "Stacked"); 
axis tight; 
grid on;
title("Win percentage");
ylabel("[%]");
legend("Plyr 1", "Plyr 2", "Location", "Best");

%% Save data
if ~exist(".\data", "dir")
	mkdir(".\data");
end

[wins, ind] = max((W1(1:end-1) + W2(1:end-1))/2);
save(fullfile(".\data", datestr(now, "ddmmyy-HHMMSS") + "_Ind"+ind + "_" ...
	+ round(wins) + "p.mat"));
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

