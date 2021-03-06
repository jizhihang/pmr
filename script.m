% PMR assignment 2
% Nov 2011
% S. M. Ali Eslami
% s.m.eslami@sms.ed.ac.uk

% Remember, there are only a limited number of licences for MATLAB. After 
% you have finished using MATLAB, quit from the MATLAB session so that 
% others can work.

%% INITIALISATION ----------------------------------------------------------

% clear the console
clc;
clear;
close all;

% add the toolboxes that we'll need for visualisation and data processing
addtoolboxes;

% load the motion capture data
[skeleton, sequence_X, frame_length] = bvhReadFile('data/mocap-anchored.bvh');
NFrames    = size(sequence_X, 1);
NFeatures  = size(sequence_X, 2);

%% DEMO --------------------------------------------------------------------

% visualise the loaded data
% skelPlayData(skeleton, sequence_X, frame_length);

%% PART 1 ------------------------------------------------------------------
%% P1Q1:
% [getEigenvectors.m]
%% P1Q2:
[Mu, E, Lambda, P] = getEigenvectors(sequence_X);
[Log, Cleanup] = makeLogFile('p1q2.log');
fprintf(Log, 'Eigenvalue %d: %4.1f\n', 1, Lambda(1));
fprintf(Log, 'Eigenvalue %d: %4.1f\n', 2, Lambda(2));
% Get the index of the first element in P which is >= 95.
NComponents = find(P >= 95, 1);
% Get its value.
Y = P(NComponents);
figure;
plot(P);
line([4 4 0 4], [50 Y Y Y]);
xlabel('number of components');
ylabel('cumulative % variance');
set(gca,'XTick',sort([0:10:NFeatures NComponents]), 'YTick',sort([0:10:100 Y]));
writeFigurePDF('p1q2.pdf');
%% P1Q3:
% Visualise the mean pose.
sequence_Y0 = makeSequence(NFrames, Mu, 0, E(:, 1));
figure;
skelPlayData(skeleton, sequence_Y0, frame_length);
writeFigurePDF('p1q3-mean.pdf');
% Visualise the first component.
sequence_Y1 = makeSequence(NFrames, Mu, Lambda(1), E(:, 1));
figure;
skelPlayData(skeleton, sequence_Y1, frame_length);
writeFigurePDF('p1q3-comp1.pdf');
% Visualise the second component.
sequence_Y2 = makeSequence(NFrames, Mu, Lambda(2), E(:, 2));
figure;
skelPlayData(skeleton, sequence_Y2, frame_length);
writeFigurePDF('p1q3-comp2.pdf');
%% P1Q4:
% Z: [NFrames x 2]
Z = projectSequence(Mu, E, sequence_X, 2);
figure;
line('XData', Z(:, 1), 'YData', Z(:, 2));
xlabel('Component 1');
ylabel('Component 2');
writeFigurePDF('p1q4.pdf');

%% PART 2 ------------------------------------------------------------------
%% P2Q1:
figure;
Net = gtm1dinittrain(sequence_X, E, 50, 7, 200);
writeFigurePDF('p2q1.pdf');
%% P2Q2:
% P: [NFrames x 1]
P = gtmprob(Net, sequence_X);
LL = sum(log(P));
[Log, Cleanup] = makeLogFile('p2q2.log');
fprintf(Log, 'Log likelihood of GTM model: %1.3e\n', LL);
%% P2Q3:
% Vary the number of RBF Centers
LLs_byNCtrs = [];
CtrValues = [2 3 5 7 11 23 31];
for NCtrs = CtrValues
    LLs_byNCtrs(end + 1) = gtmTrainAndReport(sequence_X, E, 50, NCtrs);
    writeFigurePDF(sprintf('p2q3-%ds-%dc.pdf', 50, NCtrs));
end
figure;
plot(CtrValues, LLs_byNCtrs);
writeFigurePDF('p2q3-plotByCtrs.pdf');
% Vary the number of sample points
LLs_ByNPts = [];
PtValues = [10 20 30 40 50 65 75 85 100 125 150];
for NPts = PtValues
    LLs_ByNPts(end + 1) = gtmTrainAndReport(sequence_X, E, NPts, 7);
    writeFigurePDF(sprintf('p2q3-%ds-%dc.pdf', NPts, 7));
end
figure;
plot(PtValues, LLs_ByNPts);
writeFigurePDF('p2q3-plotByPts.pdf');
%% P2Q4:
Net2D = gtm2dinittrain(sequence_X, 50, 10, 50);
% Compute the mean latent projection of the sequence
Means = gtmlmean(Net2D, sequence_X);
figure;
line('XData', Means(:, 1), 'YData', Means(:, 2));
writeFigurePDF('p2q4.pdf');

%% PART 3 ------------------------------------------------------------------
%% P3Q1:
[W,Mu,DiagPsi,~] = fa(sequence_X, 2, 50);
MMu = repmat(Mu', [NFrames 1]);
sequence_Z_FA = (sequence_X - MMu) * pinv(W)';
figure;
line('XData', sequence_Z_FA(:, 1), 'YData', sequence_Z_FA(:, 2));
writeFigurePDF('p3q1.pdf');
%% P3Q2:
% [Deleted]
%% P3Q3:
% [No code]
%% P3Q4:
LL = fallikelihood(sequence_X, W, DiagPsi, Mu);
[Log, Cleanup] = makeLogFile('p3q4.log');
fprintf(Log, 'Log likelihood of FA model: %1.3e\n', LL);
%% P3Q5:
% Compute a random permutation of the frames
% NFrames = NFrames;
% Idx : 1 x NFrames
Idx = randperm(NFrames);
% RandSeq: [NFrames x NFeatures]
RandSeq = sequence_X(Idx, :);

NFolds = 7;
FoldSize = NFrames/NFolds;
Ms = [1 2 5 10 15 20 25]';
LLTrain = zeros(size(Ms));
LLTest = zeros(size(Ms));
for MIdx = 1:size(Ms)
    M = Ms(MIdx);
    LLTrainTot = 0;
    LLTestTot = 0;
    for V = 1:NFolds
        TestSet = RandSeq(1 : FoldSize, :);
        TrainSet = RandSeq(FoldSize + 1 : NFrames, :);
        RandSeq = circshift(RandSeq, 83);
        
        [W,Mu,DiagPsi,~] = fa(TrainSet, M, 50);
        
        LLTestTot = LLTestTot + fallikelihood(TestSet, W, DiagPsi, Mu);
        LLTrainTot = LLTrainTot + fallikelihood(TrainSet, W, DiagPsi, Mu);
    end
    % Compute the average across the NFolds runs
    LLTest(MIdx) = LLTestTot/NFolds;
    LLTrain(MIdx) = LLTrainTot/NFolds;
end
% We need to scale the log likelihoods by the number of instances in order
% to make them comparable.
LLTest = LLTest * NFolds;
LLTrain = LLTrain * NFolds / (NFolds-1);
figure;
plot(Ms, LLTest, 'g');
hold on;
plot(Ms, LLTrain, 'b');
writeFigurePDF('p3q5.pdf');
%% P3Q6:
% [No code]

%% PART 4 ------------------------------------------------------------------
%% P4Q1:
% [No code]
%% P4Q2:
rand('seed', 0);
randn('seed', 0);
Net = lds(sequence_X, 2);
LL = lds_cl(Net, sequence_X, 2);
[Log, Cleanup] = makeLogFile('p4q2.log');
fprintf(Log, 'Log likelihood of LDS model: %1.3e\n', LL);
% Compute the angle between the subspaces defined by C and W
Theta = subspace(Net.C, W);
fprintf(Log, 'Angle between subspaces of C and W: %3.3e (radians)\n', Theta);
%% P4Q3:
% [No code]
%% P4Q4:
[sequence_Z_LDS, V] = ldspost(sequence_X, Net);
figure;
line('XData', -sequence_Z_LDS(:, 2), 'YData', -sequence_Z_LDS(:, 1));
writeFigurePDF('p4q4.pdf');
%% P4Q5:
MMu = repmat(Net.Mu, [NFrames 1]);
sequence_Y_reconstructed = sequence_Z_LDS * Net.C' + MMu;
figure;
skelPlayData(skeleton, sequence_Y_reconstructed, frame_length);
%% P4Q6:
% Without noise
[sequence_Y_sampled, sequence_Z_sampled] = ldsSample(NFrames, Net, 0);
figure;
line('XData', -sequence_Z_sampled(:, 2), 'YData', -sequence_Z_sampled(:, 1));
writeFigurePDF('p4q6-nonoise.pdf');
figure;
skelPlayData(skeleton, sequence_Y_sampled, frame_length);
% With noise
[sequence_Y_sampled, sequence_Z_sampled] = ldsSample(NFrames, Net, 1);
figure;
line('XData', -sequence_Z_sampled(:, 2), 'YData', -sequence_Z_sampled(:, 1));
writeFigurePDF('p4q6-withnoise.pdf');
figure;
skelPlayData(skeleton, sequence_Y_sampled, frame_length);
%% P4Q7:
% [No code]
%% P4Q8:
% [No code]

%% Cleanup
fclose('all');
