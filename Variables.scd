~visuals = false; // For multiplying the complex spectrum of individuals

~multiplyOn = true; // For multiplying the complex spectrum of individuals

~mutationOn = true;

~zeroPhaseOn = false;

~mutationWidth = 0.2;

~xOverProb = 0.7; // Probability of crossover (0 - 1)

~parentTuplesFrac = 0.5; // Number of tuples (parent couples or triples) determined as a fraction of the number of chosen parents

~parentFrac = 0.5; // Fraction of adults to become parents

~envInsert = true; // For inserting a snippet of the environment into the genome of an individual
~envInsertProb = 0.2;

~spectralEnvelopeOn = false; // For attenuating the high frequencies of the spectrum

~ancestorReturn = true;
~ancestorReturnProb = 0.07;
// Fitness Variables. For balancing the parameters contributing to calculating the fitness function
~slicepointCoeff = 0; // Biases toward shorter attcack
~specCentDevGenoCoeff = 1.0; // The deviation of the spectral centroid, calculated from the genome
~specCentDevPhenoCoeff = 1.0; // The deviation of the spectral centroid, calculated from the phenome.
~distanceModerator = 0; // If using the lower distance to the spectral centroid. Currently not in use

// The width of the snippet of the environments spectrum that will be inserted into an individual. 0 is nothing, 1 equals the entire range between cut point and the next value on the bark scale
~envInsertWidth = 0.1;

~envRecLength = 2;

~mutationCoeff = 0.5;

~adultAge = 5;
~retirementAge = 12;

~newGenPopSize = 15;

~deathProb = 0.3;

~ancestralMemory = 4; // How many generations (as audio buffers) are stored
~sigBufRedundancy = 4; // For storing and freeing ir buffers
~genCounter = 0;
~numPop = 4;
~cycleGenInd = 0;
~convolveFftsize = 4096;

~toBlackhole = 16;

~mainOut = 0;

~micInMono = 0;

~micInStereo = [0, 1];

~bufPlayMaxWaitTime = 1.5;

~numEnvironments = 4;

~envirIrOn = true;

~postInfo = ~numEnvironments.collect{false};

~roomIrPlaying = false;

s.latency = 0.1;
