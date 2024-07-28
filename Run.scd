MIDIFunc.trace(true);
MIDIFunc.trace(false);

s.plotTree;

"NewGeneration_1.7.scd".loadRelative; // Evaluate me

~tasks[0].start; // Begin playback and evolution
~tasks[0].pause;
~tasks[0].resume;
~tasks[0].stop;


// Volume controls
~convolveMix.set(0); // Wet-dry convolution mix. Convolution operates in the feedback chain. -1 = off, 1 = fully convolved. If using a nanoKontrol, mapped to dial 2

~feedbackVol.set(0.5); // 0 - 1. Controls the gain of the microphone. NanoKontrol: slider 2

~irVolume.set(0.5); // 0 - 1. Volume of the playback of the irs. NanoKontrol: slider 3

~masterVol.set(0.5); // 0 -1. Master volume. NanoKontrol: slider 1



// EA variables (see Variables.scd for setting these at compile time

~xOverProb = 0.7; // Probability of crossover (0 - 1)

~mutationOn = true;

~zeroPhaseOn = false;

~multiplyOn = true; // For multiplying the complex spectrum of individuals

~mutationWidth = 10; // Measured in frequencies

// ~mutationProb = 0.001; mutation is currently a function of the size of the population, so this is not in use

~envInsert = true; // For inserting a snippet of the environment into the genome of an individual

~spectralEnvelopeOn = true; // For attenuating the high frequencies of the spectrum

// Fitness Variables. For balancing the parameters contributing to calculating the fitness function. All values are between 0 and 1
~slicepointCoeff = 0.0; // Biases toward shorter attcack
~specCentDevGenoCoeff = 1.0; // The deviation of the spectral centroid, calculated from the genome
~specCentDevPhenoCoeff = 1.0; // The deviation of the spectral centroid, calculated from the phenome.
~distanceModerator = 0; // If using the lower distance to the spectral centroid. Currently not in use

// The width of the snippet of the environments spectrum that will be inserted into an individual. 0 is nothing, 1 equals the entire range between cut point and the next value on the bark scale
~envInsertWidth = 0.2;
