MIDIFunc.trace(true);
MIDIFunc.trace(false);

s.plotTree;

"NewGeneration_1.7.scd".loadRelative; // Evaluate me

~tasks[0].start; // Begin playback and evolution
~tasks[0].pause;
~tasks[0].resume;
~tasks[0].stop;
~tasks[0].reset;

~tasks[1].start; // Begin playback and evolution
~tasks[1].pause;
~tasks[1].resume;
~tasks[1].stop;
~tasks[1].reset;

~tasks[0].start;
~tasks[1].start;
~tasks[2].start;
~tasks[3].start;



~postInfo[0] = true;
~postInfo[1] = true;
~postInfo[2] = true;
~postInfo[3] = true;

~feedbackVol[0].set(0.3); // 0 - 1. Controls the gain of the microphone. NanoKontrol: slider 2

~irVolume[0].set(0.2); // 0 - 1. Volume of the playback of the irs. NanoKontrol: slider 3

~masterVol.set(1); // 0 -1. Master volume. NanoKontrol: slider 1

~convolveMix[0].set(1); // Wet-dry convolution mix. Convolution operates in the feedback chain. -1 = off, 1 = fully convolved. If using a nanoKontrol, mapped to dial 2

~feedbackThreshBus[0].set(0.01);

~feedbackVol[1].set(0.9); // 0 - 1. Controls the gain of the microphone. NanoKontrol: slider 2

~irVolume[1].set(0.8); // 0 - 1. Volume of the playback of the irs. NanoKontrol: slider 3

~convolveMix[1].set(0.5); // Wet-dry convolution mix. Convolution operates in the feedback chain. -1 = off, 1 = fully convolved. If using a nanoKontrol, mapped to dial 2

~envirIrAmpBus[1].set(0.3);

~feedbackThreshBus[1].set(0.01);

~numEnvironments.collect{|i|
	~irVolume[i].set(0.8);
	~feedbackVol[i].set(0.4);
	~feedbackThreshBus[i].set(0.01);
	~convolveMix[i].set(0.5);
	~envirIrAmpBus[i].set(0.2);
}

(
~adultAge = 5;
~retirementAge = 10;

~deathProb = 0.5;

~visuals = false;

// Volume controls

// EA variables (see Variables.scd for setting these at compile time

~xOverProb = 0.7; // Probability of crossover (0 - 1)

~mutationOn = true;

~zeroPhaseOn = false;

~multiplyOn = true; // For multiplying the complex spectrum of individuals

~mutationWidth = 0.5;

~ancestorReturn = true;
~ancestorReturnProb = 0.1;

~envirIrOn = true;

// ~mutationProb = 0.001; mutation is currently a function of the size of the population, so this is not in use

~envInsert = true; // For inserting a snippet of the environment into the genome of an individual

~spectralEnvelopeOn = false; // For attenuating the high frequencies of the spectrum
~envRecLength = 2.0;

~mutationCoeff = 0.2;

// Fitness Variables. For balancing the parameters contributing to calculating the fitness function. All values are between 0 and 1
~slicepointCoeff = 1; // Biases toward shorter attacks. Seems to favour darker irs when above 0
~specCentDevGenoCoeff = 1.0; // The deviation of the spectral centroid, calculated from the genome
~specCentDevPhenoCoeff = 1.0; // The deviation of the spectral centroid, calculated from the phenome.
~distanceModerator = 0; // If using the lower distance to the spectral centroid. Currently not in use

// The width of the snippet of the environments spectrum that will be inserted into an individual. 0 is nothing, 1 equals the entire range between cut point and the next value on the bark scale. If set very high, it works like a sampler, inserting recognizable audio into irs.
~envInsertWidth = 0.4;

~bufPlayMaxWaitTime = 1.5; // The maximum time added to the wait time between individual buffers playing
)
