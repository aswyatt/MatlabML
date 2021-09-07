%	Initialise script
Proj = currentProject;
rng(0);

%	Create Agent Options
agentOpts = rlQAgentOptions;
agentOpts.EpsilonGreedyExploration.Epsilon = .1;
agentOpts.EpsilonGreedyExploration.EpsilonDecay = 1e-3;
agentOpts.EpsilonGreedyExploration.EpsilonMin = 1e-3;

%	Set training options
trainOpts = rlTrainingOptions;
trainOpts.MaxStepsPerEpisode = 10;
trainOpts.MaxEpisodes= 1000;
trainOpts.StopTrainingCriteria = "EpisodeCount";
trainOpts.StopTrainingValue = trainOpts.MaxEpisodes;
trainOpts.Plots = "None";


%	Train the agent
obj = TrainingObj("NumAgents", 3, "LearnRate", .5, "AgentOpts", agentOpts);
obj.Train(1000, trainOpts);
arrayfun(@(A) sum(cell2mat(getLearnableParameters(getCritic(A))), ...
	"all", "omitnan"), obj.Agents)

%%

T = TicTacToe;
Na = length(obj.Agents);
Ni = 1000;
P = zeros(Na, Na, 3);
for ni=1:Ni
	ind = randsample(1:Na, 2);
	Agents = obj.Agents(ind);
	T.Reset;
	W = 0;
	while ~W
		T.Choose("Agent", Agents(T.CurrentPlayer));
		W = T.CheckWinner;
	end
	if W<0
		P(ind(1), ind(2), 3) = P(ind(1), ind(2), 3) + 1;
	else
		P(ind(1), ind(2), W) = P(ind(1), ind(2), W) + 1;
	end
end

clf;
tiledlayout(1, 3, "Padding", "Tight", "TileSpacing", "Compact");
str = ["Player 1" "Player 2" "Draw"];
for n=1:3
	ax = nexttile;
	bar3(P(:, :, n));
	title(str(n));
	xlabel("Player 1 Agent");
	ylabel("Player 2 Agent");
end