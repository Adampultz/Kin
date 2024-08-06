~populations = {|popIndex, signals, newGeneration|
	var newSigs, newSigBufs, run, featureBuffersGeno, newGen, spectralCentroidGeno, environment, slicePointArray, spectralCentroidDevPheno, genCounter, envRecOn, envRecBuf, popOutputRecBuf;

	envRecOn = false;
	genCounter = 0;
	newSigs = signals.deepCopy;

	newGen = ~sigBufRedundancy.collect{};
	newSigBufs = ~sigBufRedundancy.collect{};
	newSigBufs[genCounter] = newSigs.size.collect{|i| Buffer.loadCollection(s, newSigs[i])}; // Load Signal buffers to standard buffers
	spectralCentroidGeno = newSigs.size.collect{}.asList; // Spectral centroid of the irs spectrum
	slicePointArray = newSigs.size.collect{}.asList; // List for holding individual slice points of buffers
	featureBuffersGeno = newSigBufs[genCounter].size.collect{Buffer(s, numChannels: 1)}.asList; // Spectral centroid of the irs spectrum estimated by the microphones
	spectralCentroidDevPheno = newSigs.size.collect{}.asList; // Deviation of the spectral centroid of individuals compared to the spectral centroid of the environment

	newGen[genCounter] = newGeneration.deepCopy;

	envRecBuf = Buffer.alloc(s, s.sampleRate * ~envRecLength);
	popOutputRecBuf = Buffer.alloc(s, s.sampleRate * ~envRecLength);

	s.sync;

	// Routine for starting playback and evolution
	~tasks[popIndex] = Task({ // Initial playback and statistics
		var distanceBelow, stats, parents,couples, cycleGenInd = 0, fitness;

		"Generation: %".format(genCounter).postln;

		// Routine for starting and stopping the recording of the environment
		if (envRecOn == false, {
			Routine{ 1.do {
				envRecOn = true;
				"Recording environment on".postln;
				environment = ~recEnv.(envRecBuf, popOutputRecBuf, ~rfftParams[0], ~rfftParams[2]);
				(popOutputRecBuf.numFrames / s.sampleRate).wait;
				"Recording environment off".postln;
				envRecOn = false;
			}}.play;
		});

		// Determine slice points for all irs and extract statistics (genotype)
		newSigBufs[cycleGenInd].size.collect{|i|
			var slice, slicePoint;

			// Expand featureBuffers list if needed
			if (i >= featureBuffersGeno.size, {featureBuffersGeno.add(Buffer(s, numChannels: 1));
				spectralCentroidGeno.add(0);
				slicePointArray.add(0)
			});

			// Identify slice points for measuring spectral centroid
			// slice = ~ampSlice.(newSigBufs[cycleGenInd][i]);
			slice = newSigBufs[cycleGenInd][i].ampSlice(s, windowSize: 2048);

			// Store slicepoints for use in real-time centroid detection
			slice.get(1, {|msg|
				if (i >= slicePointArray.size, {
					slicePointArray.add(msg);
				}, {
					slicePointArray[i] = msg;
				});
			});

			s.sync;
			// Extract statistics about ir
			FluidBufSpectralShape.processBlocking(s, newSigBufs[cycleGenInd][i], 0, slicePointArray[i], select: [\centroid], features: featureBuffersGeno[i], windowSize: 2048);

			featureBuffersGeno[i].loadToFloatArray(action: {|array|  spectralCentroidGeno[i] = array.asArray.mean}); // Load from buffer to array of floats
		};

		s.sync;

		// Playback routine of irs
		~playBufs.(newSigBufs[cycleGenInd], slicePointArray);

		// Update spectral features of each individual, extracted from the environment (phenotype)
		newSigBufs[cycleGenInd].size.do({|i|
			if(i < spectralCentroidDevPheno.size, {
				spectralCentroidDevPheno[i] = ~specCentAvgBus[i].getSynchronous},{
				spectralCentroidDevPheno.add(~specCentAvgBus[i].getSynchronous)
			});
		});

		"onwards".postln;

		genCounter = genCounter + 1;

		s.sync;

		inf.do{
			var currentGen;

			"Generation: %".format(genCounter).postln;

			cycleGenInd = cycleGenInd + 1;

			if(cycleGenInd > (~ancestralMemory - 1),
				{cycleGenInd = 0});

			currentGen = newGen[cycleGenInd];

			distanceBelow = ~distanceBelow.(spectralCentroidGeno); // Measure how far below the spectral centroid of each individual is to the mean spectral centroid

			// Deviation, spectral centroid, and standard deviation (SD)
			stats = ~stats.(spectralCentroidGeno.asArray.normalizeSum);

			"Stats: %".format(stats[0]).postln;
			"Spec Centroid Geno: %".format(spectralCentroidDevPheno.asArray.normalizeSum).postln;
			"Spec Centroid Phenotype: %".format(spectralCentroidGeno.asArray.normalizeSum).postln;
			// "Slice array: %".format(slicePointArray.asArray.normalizeSum).postln;

			// Sum various audio features and statistics to a single fitnes measure
			fitness = ((stats[0] * ~specCentDevGenoCoeff) + (spectralCentroidDevPheno.asArray.normalizeSum * ~specCentDevPhenoCoeff) + ((1 / slicePointArray.asArray.normalizeSum) * ~slicepointCoeff) + distanceBelow).normalizeSum;
			"Fitness: %".format(fitness).postln;
			// ~variancePlot.add(stats[1]);

			// Weighted selection of parents with no repetition
			// parents = ~wchooseNorepeat.(fitness, (fitness.size * 0.7).round.asInteger);
			parents = fitness.wChooseNorepeat((fitness.size * 0.7).round.asInteger);
			"Parents: %".format(parents).postln;
			newGen.postln;

			"new generation: %".format(newGen[(cycleGenInd - 1) % 4]).postln;

			// Generate a selection of couples.
			couples = parents.pairsNoRep((newGen[(cycleGenInd - 1) % 4].size / 2).round.asInteger);

			"Couples: %".format(couples).postln;

			newGen[cycleGenInd] = couples.size.collect{|i| ~newPop.(newGen[(cycleGenInd - 1) % 4], ~rfftParams[1], couples[i], 0.7)}.flat.asList;

			if (~mutationOn == true, {
				newGen[cycleGenInd].size.do{
					if ((1.0 / newGen[cycleGenInd].size).coin == true, {
						var which = newGen[cycleGenInd].size.rand;
						newGen[cycleGenInd][which] = ~mutationRho.(newGen[cycleGenInd][which], ~mutationWidth);
						"Mutation of individual %".format(which).postln;
					});
				};
			});

			if (~multiplyOn == true, {
				if (0.25.coin == true, {
					var whichCouple = couples.choose;
					var whichNewIndividual = newGen[cycleGenInd].size.rand;
					var whichIndividuals = 2.collect{|i| newGen[cycleGenInd][whichCouple[i]]};
					// var newMultiply = ~multiplyComplex.(whichIndividuals);
					var newMultiply = ~multiplyPolar.(whichIndividuals);
					s.sync;
					newGen[cycleGenInd].add(newMultiply);
					"Multiply of couple %".format(whichCouple).postln;
				});
			});

			if (~zeroPhaseOn == true, {
				if (0.1.coin == true, {
					var which = newGen[cycleGenInd].size.rand;
					newGen[cycleGenInd][which] = ~zeroPhase.(newGen[cycleGenInd][which]);
					"Zero phases on %".format(which).postln;
				});
			});

			if (~envInsert && envRecOn.not, {
				if (~envInsertProb.coin == true, {
					var which = newGen[cycleGenInd].size.rand;
					if (0.5.coin == true, {
					newGen[cycleGenInd][which] = ~insertEnvSpectrum.(newGen[cycleGenInd][which], environment[1], ~envInsertWidth);
					"Environment Insert %".format(which).postln;
					}, {
						newGen[cycleGenInd][which] = ~insertEnvAudio.(newGen[cycleGenInd][which], envRecBuf, ~envInsertWidth);
					"Environment Audio Insert %".format(which).postln;
					})
				});
			});


			if (~spectralEnvelopeOn == true,{ // TODO: polar multiplication
				newGen[cycleGenInd].do{|item|
					var polar;
					polar = item.asPolar;
					polar.rho = polar.rho * ~fourierEnv;
					item = polar.real.as(Signal).complex(polar.imag.as(Signal));
				};
			});

			if (~ancestorReturn == true, {
				if (~ancestorReturnProb.coin == true,{
					"Ancestor returns".postln;
					newGen[cycleGenInd].add(~parentFreqResp.choose)
				})
			});

			// For plotting spectrums
			// ~monitor = newGen[cycleGenInd];

			newSigs = newGen[cycleGenInd].size.collect{|i|
				~newGeneration.(newGen[cycleGenInd][i], ~rfftParams[2], ~audioEnv, ~fourierEnv);
			};


			{~freqResponsevisualise.(newGen[cycleGenInd])}.defer;

			// Free buffers not in use.
			newSigBufs[(cycleGenInd + 1) % ~sigBufRedundancy].do({ arg i;
				if(i != nil, {
					i.free;
					i = nil;
				});
			});

			s.sync;

			newSigBufs[cycleGenInd] = newSigs.size.collect{|i| Buffer.loadCollection(s, newSigs[i])};

			s.sync;

			if (envRecOn.not, {
				Routine{ 1.do {
					envRecOn = true;
					"Recording environment on".postln;
					environment = ~recEnv.(envRecBuf, popOutputRecBuf, ~rfftParams[0], ~rfftParams[2]);
					(popOutputRecBuf.numFrames / s.sampleRate).wait;
					"Recording environment off".postln;
					envRecOn = false;
				}}.play;
			});

			newSigBufs[cycleGenInd].size.collect{|i|
				var slice, slicePoint;

				// Expand featureBuffers list if needed
				if (i >= featureBuffersGeno.size, {featureBuffersGeno.add(Buffer(s, numChannels: 1));
					spectralCentroidGeno.add(0);
					slicePointArray.add(0)
				});

				// Identify slice points for measuring spectral centroid
				// slice = ~ampSlice.(newSigBufs[cycleGenInd][i]);
				slice = newSigBufs[cycleGenInd][i].ampSlice(s, windowSize: 2048);

				// Store slicepoints for use in real-time centroid detection
				slice.get(1, {|msg|
					if (i >= slicePointArray.size, {
						slicePointArray.add(msg);
					}, {
						slicePointArray[i] = msg;
					});
				});

				s.sync;

				FluidBufSpectralShape.processBlocking(s, newSigBufs[cycleGenInd][i], 0, slicePointArray[i], select: [\centroid], features: featureBuffersGeno[i], windowSize: 2048);

				featureBuffersGeno[i].loadToFloatArray(action: {|array|  spectralCentroidGeno[i] = array.asArray.mean});
			};

			if (0.5.coin == true, {
				"New convolution spectrum".postln;
				~xFadeFbConvolve.(newSigBufs[cycleGenInd], ~convolveFftsize, 2)});

			s.sync;

			~playBufs.(newSigBufs[cycleGenInd], slicePointArray);

			// Update spectral features of each individual
			newSigBufs[cycleGenInd].size.do({|i|
				if(i < spectralCentroidDevPheno.size, {
					spectralCentroidDevPheno[i] = ~specCentAvgBus[i].getSynchronous},{
					spectralCentroidDevPheno.add(~specCentAvgBus[i].getSynchronous)
				});
			});

			genCounter = genCounter + 1;

			s.sync;

		};

	});
};
