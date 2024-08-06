~multiplyOn = true; // For multiplying the complex spectrum of individuals

~mutationOn = true;

~zeroPhaseOn = false;

~mutationWidth = 100; // Measured in frequencies

~xOverProb = 0.7; // Probability of crossover (0 - 1)

// ~mutationProb = 0.001; mutation is currently a function of the size of the population, so this is not in use

~envInsert = true; // For inserting a snippet of the environment into the genome of an individual
~envInsertProb = 0.2;

~spectralEnvelopeOn = true; // For attenuating the high frequencies of the spectrum

~ancestorReturn = true;
~ancestorReturnProb = 0.1;
// Fitness Variables. For balancing the parameters contributing to calculating the fitness function
~slicepointCoeff = 1; // Biases toward shorter attcack
~specCentDevGenoCoeff = 1.0; // The deviation of the spectral centroid, calculated from the genome
~specCentDevPhenoCoeff = 1.0; // The deviation of the spectral centroid, calculated from the phenome.
~distanceModerator = 1; // If using the lower distance to the spectral centroid. Currently not in use

// The width of the snippet of the environments spectrum that will be inserted into an individual. 0 is nothing, 1 equals the entire range between cut point and the next value on the bark scale
~envInsertWidth = 0.1;

~envRecLength = 2;

~mutationCoeff = 0.5;

~ancestralMemory = 4; // How many generations (as audio buffers) are stored
~sigBufRedundancy = 4; // For storing and freeing ir buffers
~genCounter = 0;
~numPop = 4;
~cycleGenInd = 0;
~pebble = 0;
~convolveFftsize = 4096;

s.latency = 0.1;

~toBlackhole = 16;

~mainOut = 0;

~micInMono = 0;

~micInStereo = [0, 1];
