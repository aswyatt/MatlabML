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