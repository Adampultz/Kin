~populations = {|popIndex, signals, newGeneration|
	var newSigs, newBufs, run, featureBuffersGeno, newGen, spectralCentroidGeno, spectralCentroidGenoParents, environment, slicePointArray, spectralCentroidDevPheno, spectralCentroidDevPhenoParents, genCounter, envRecOn, envRecBuf, popOutputRecBuf, age, lifeCycle, adultIndices, adults, seniors, adultFitness, pebble, inSynth, feedbackSynths, convolveSpectrum, initConvolveBuf;

	feedbackSynths = 2.collect{};
	adults = [].asList;
	seniors = [].asList;
	envRecOn = false;
	genCounter = 0;
	newSigs = signals.deepCopy.asList;

	pebble = 0;

	initConvolveBuf = Buffer.loadCollection(s, newSigs.choose);

	s.sync;

	convolveSpectrum = ~prepConvolve.(initConvolveBuf, ~convolveFftsize).normalize;

	s.sync;

	inSynth = Synth(\soundIn, [\audioIn, popIndex, \envCentAvg, ~envCentAvg[popIndex], \envCent, ~envCent[popIndex], \envSpread, ~envSpread[popIndex]], target: ~envGrp);

	feedbackSynths[0] = Synth(\feedBack, [\irBuffer, convolveSpectrum.bufnum, \fftSize, ~convolveFftsize, \feedbackVol, ~feedbackVol[popIndex], \convolveMix, ~convolveMix[popIndex], \micChan, 1], target: ~convolveGrp);

	s.sync;

	newGen = ~sigBufRedundancy.collect{[].asList};
	newBufs = ~sigBufRedundancy.collect{};
	newBufs[genCounter] = newSigs.size.collect{|i| Buffer.loadCollection(s, newSigs[i][0..~maximumSize])}; // Load Signal buffers to standard buffers
	spectralCentroidGeno = newSigs.size.collect{}.asList; // Spectral centroid of the irs spectrum
	slicePointArray = newSigs.size.collect{}.asList; // List for holding individual slice points of buffers
	featureBuffersGeno = newBufs[genCounter].size.collect{Buffer(s, numChannels: 1)}.asList; // Spectral centroid of the irs spectrum estimated by the microphones
	spectralCentroidDevPheno = newSigs.size.collect{}.asList; // Deviation of the spectral centroid of individuals compared to the spectral centroid of the environment

	newGen[genCounter] = newGeneration.deepCopy;
	age = List.fill(newGen[genCounter].size, {0});
	lifeCycle = List.fill(newGen[genCounter].size, {0});

	// Register life cycle of individuals. 0 = child, 1 = adult, 2 = retiree
	age.size.do{|i|
		var val;
		val = age[i];

		x = case
		{val < ~adultAge} {lifeCycle[i] = 0}
		{(val >= ~adultAge) && (val < ~retirementAge)} {lifeCycle[i] = 1}
		{val >= ~retirementAge} {lifeCycle[2] = 2};
	};


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
				environment = ~recEnv.(envRecBuf, popOutputRecBuf, ~rfftParams[0], ~rfftParams[2], popIndex);
				(popOutputRecBuf.numFrames / s.sampleRate).wait;
				// "Recording environment off".postln;
				envRecOn = false;
			}}.play;
		});

		// Determine slice points for all irs and extract statistics (genotype)
		newBufs[cycleGenInd].size.collect{|i|
			var slice, slicePoint;
			// Expand featureBuffers list if needed
			if (i >= featureBuffersGeno.size, {featureBuffersGeno.add(Buffer(s, numChannels: 1));
				spectralCentroidGeno.add(0);
				slicePointArray.add(0)
			});


			// Identify slice points for measuring spectral centroid
			// slice = ~ampSlice.(newBufs[cycleGenInd][i]);
			slice = newBufs[cycleGenInd][i].ampSlice(s, windowSize: 2048);

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
			FluidBufSpectralShape.processBlocking(s, newBufs[cycleGenInd][i], 0, slicePointArray[i], select: [\centroid], features: featureBuffersGeno[i], windowSize: 2048);

			featureBuffersGeno[i].loadToFloatArray(action: {|array|  spectralCentroidGeno[i] = array.asArray.mean}); // Load from buffer to array of floats
		};

		s.sync;

		// Playback routine of irs
		~playBufs.(popIndex, newBufs[cycleGenInd], slicePointArray, popIndex);

		// Update spectral features of each individual, extracted from the environment (phenotype)
		newBufs[cycleGenInd].size.do({|i|
			if(i < spectralCentroidDevPheno.size, {
				spectralCentroidDevPheno[i] = ~specCentAvgBus[popIndex][i].getSynchronous},{
				spectralCentroidDevPheno.add(~specCentAvgBus[popIndex][i].getSynchronous)
			});
		});

		"onwards".postln;

		genCounter = genCounter + 1;

		s.sync;

		inf.do{
			var currentGen, parentsGen, children, numAdults, deathCount, modIDs, numNewIndividuals, newTempBuffers;

			deathCount = 0;
			numNewIndividuals = 0;

			modIDs = [].asList; // List for holding indexes of changed individuals

			"Generation: %".format(genCounter).postln;

			parentsGen = cycleGenInd;

			cycleGenInd = cycleGenInd + 1;

			if(cycleGenInd > (~ancestralMemory - 1),
				{cycleGenInd = 0});

			currentGen = newGen[cycleGenInd];

			age.size.collect{|i|
				age[i] = age[i] + 1;

				// Register life cycle of individuals. 0 = child, 1 = adult, 2 = retiree

				x = case
				{age[i] < ~adultAge} {lifeCycle[i] = 0}
				{(age[i] >= ~adultAge) && (age[i] < ~retirementAge)} {lifeCycle[i] = 1}
				{age[i] >= ~retirementAge} {lifeCycle[i] = 2;
					if(~deathProb.coin, {
						newGen[parentsGen][i] = nil;
						lifeCycle[i] = nil;
						age[i] = nil;
						spectralCentroidGeno[i] = nil;
						spectralCentroidDevPheno[i] = nil;
						slicePointArray[i] = nil;
						featureBuffersGeno[i] = nil;
						newSigs[i] = nil;
						"Death of Individual %".format(i).postln;
						deathCount = deathCount + 1;
					});
				};
			};

			// "DeathCount: %".format(deathCount).postln;

			deathCount.do{|i|
				"test".postln;
				newGen[parentsGen].remove(nil);
				lifeCycle.remove(nil);
				age.remove(nil);
				spectralCentroidGeno.remove(nil);
				spectralCentroidDevPheno.remove(nil);
				slicePointArray.remove(nil);
				featureBuffersGeno.remove(nil);
				newSigs.remove(nil);
				newBufs[parentsGen].remove(nil);
			};


/*			"Parent gen size: %".format(newGen[parentsGen].size).postln;
			"Life cycle Size: %".format(lifeCycle.size).postln;
			"Life cycle: %".format(lifeCycle).postln;
			"Age Size: %".format(age.size).postln;*/

			distanceBelow = ~distanceBelow.(spectralCentroidGeno); // Measure how far below the spectral centroid of each individual is to the mean spectral centroid

			// Deviation, spectral centroid, and standard deviation (SD)

			/*			adultIndices = lifeCycle.indicesOfEqual(1);
			"Adults: %".format(adultIndices).postln;*/

			stats = ~stats.(spectralCentroidGeno.asArray.normalizeSum);

			/*			"Stats: %".format(stats[0]).postln;
			"Spec Centroid Geno: %".format(spectralCentroidDevPheno.asArray.normalizeSum).postln;
			"Spec Centroid Phenotype: %".format(spectralCentroidGeno.asArray.normalizeSum).postln;*/
			// "Slice array: %".format(slicePointArray.asArray.normalizeSum).postln;



			// Sum various audio features and statistics to a single fitness measure
			// fitness = ((stats[0] * ~specCentDevGenoCoeff) + (spectralCentroidDevPheno.asArray.normalizeSum * ~specCentDevPhenoCoeff) + ((1 / slicePointArray.asArray.normalizeSum) * ~slicepointCoeff) + distanceBelow);

			// "Fitness Size: %".format(fitness.size).postln;

			// Set children's fitness to 0 to avoid them entering the parent race
			adultFitness = newGen[parentsGen].size.collect{|i|
				if (lifeCycle[i] != 0, {
					((stats[0][i] * ~specCentDevGenoCoeff) + (spectralCentroidDevPheno.asArray.normalizeSum[i] * ~specCentDevPhenoCoeff) + ((1 / slicePointArray.asArray.normalizeSum[i]) * ~slicepointCoeff) + distanceBelow[i] * ~distanceModerator);
				}, {0})
			};

			adultFitness = adultFitness.normalizeSum;

			// "AdultFitness: %".format(adultFitness).postln;
			// fitness = fitness.normalizeSum;

			// ~variancePlot.add(stats[1]);

			// Weighted selection of parents with no repetition
			// parents = adultFitness.wChooseNorepeat((fitness.size * 0.7).round.asInteger);
			// parents = fitness.wChooseNorepeat((fitness.size * 0.7).round.asInteger);
			// "Parents: %".format(parents).postln;
			// newGen.postln;

			// Generate a selection of couples.
			// couples = parents.tupleRandNoRep(2, (newGen[parentsGen].size / 2).round.asInteger);

			/*"Couples: %".format(couples).postln;*/

			numAdults = lifeCycle.indicesOfEqual(1).size;

			if (numAdults >= 4, {
				parents = adultFitness.wChooseNorepeat((numAdults * 0.7).round.asInteger);
				// "Parents: %".format(parents).postln;
				couples = parents.tupleRandNoRepRandSize(2, 3, (numAdults / 2).round.asInteger);

				"Couples: %".format(couples).postln;

				children = [].asList;

				couples.size.collect{|i|

					if (~xOverProb.coin, {
						var newPop;
						if(couples[i].size == 3, {
							newPop = ~newPop3Parents.(newGen[parentsGen], ~rfftParams[1], couples[i])[0];
							"3 parents".postln;
						}, {
							newPop = ~newPop.(newGen[parentsGen], ~rfftParams[1], couples[i], 0.2)[0]});

						children.add(newPop);

						age.add(0);
						lifeCycle.add(0);
						numNewIndividuals = numNewIndividuals + 1;
					})
				};

				// children = children;
				// children.postln;


				newGen[cycleGenInd] = (newGen[parentsGen] ++ children).asList;

			}, {newGen[cycleGenInd] = newGen[parentsGen]});

			if (~mutationOn == true, {
				newGen[cycleGenInd].size.do{
					if ((1.0 / newGen[cycleGenInd].size).coin == true, {
						var which = newGen[cycleGenInd].size.rand;
						var gainMod = 0.2.rrand(0.8); // Gain modification factor (0 - 1)
						newGen[cycleGenInd][which] = ~mutationRho.(newGen[cycleGenInd][which], ~mutationWidth, gainMod);
						if (modIDs.indicesOfEqual.(which) == nil, {modIDs.add(which)});
						"Mutation of individual %".format(which).postln;
					});
				};
			});


			if (~multiplyOn == true, {
				if (0.25.coin == true, {
					var whichIndividuals =  newGen[cycleGenInd].chooseNoRepeat(2);
					var newMultiply = ~multiplyPolar.(whichIndividuals);
					s.sync;
					newGen[cycleGenInd].add(newMultiply);
					age.add(0);
					lifeCycle.add(0);
					numNewIndividuals = numNewIndividuals + 1;
					"Multiply".postln;
				});
			});

			if (~zeroPhaseOn, {
				if (0.1.coin == true, {
					var which = newGen[cycleGenInd].size.rand;
					newGen[cycleGenInd][which] = ~zeroPhase.(newGen[cycleGenInd][which]);
					if (modIDs.indicesOfEqual.(which) == nil, {modIDs.add(which)});
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
					});
					if (modIDs.indicesOfEqual.(which) == nil, {modIDs.add(which)});
				});
			});

			"Envelope".postln;

			if (~spectralEnvelopeOn == true,{
				newGen[cycleGenInd].do{|item, idx|
					var polar;
					polar = item.asPolar;
					polar.rho = polar.rho * ~fourierEnv;
					item = polar.polarToComplexSignal;
				};
			});

			if (~ancestorReturn == true, {
				if (~ancestorReturnProb.coin == true,{
					"Ancestor returns".postln;
					newGen[cycleGenInd].add(~parentFreqResp.choose);
					age.add(5);
					lifeCycle.add(1);
					numNewIndividuals = numNewIndividuals + 1;
				})
			});

			// For plotting spectrums
			// ~monitor = newGen[cycleGenInd];

			// "New Signals".postln;

			// "Mod IDs: %".format(modIDs).postln;

			// "Test discrep: %".format([numNewIndividuals, newSigs.size, newGen[cycleGenInd].size]).postln;

			// Update already existing signals with mutations, etc.
			modIDs.do{|i|
				if (i < (newSigs.size - 1), {
					newSigs[i] = ~newGeneration.(newGen[cycleGenInd][i], ~rfftParams[2], ~audioEnv);
				});
			};

			numNewIndividuals.collect{|i|
				var idx, newIndividual;
				idx = newGen[cycleGenInd].size - numNewIndividuals + i;
				newIndividual = ~newGeneration.(newGen[cycleGenInd][idx], ~rfftParams[2], ~audioEnv);
				newSigs.add(newIndividual);
			};

			// "Test discrep again: %".format([numNewIndividuals, newSigs.size, newGen[cycleGenInd].size]).postln;

			/*	newSigs = newGen[cycleGenInd].size.collect{|i|
			~newGeneration.(newGen[cycleGenInd][i], ~rfftParams[2], ~audioEnv);
			};
			*/

			if (~visuals, {
				{~freqResponsevisualise.(newGen[cycleGenInd])}.defer;
			});

			// Free buffers not in use.
			/*			newBufs[(cycleGenInd + 1) % ~sigBufRedundancy].do({ arg i;
			if(i != nil, {
			i.free;
			i = nil;
			});
			});*/

			s.sync;


			// newBufs[cycleGenInd] = newSigs.size.collect{|i| Buffer.loadCollection(s, newSigs[i][0..~maximumSize])};

			modIDs.do{|i|
				if (i < (newBufs[parentsGen].size - 1), {
					newBufs[parentsGen][i] = Buffer.loadCollection(s, newSigs[i][0..~maximumSize]);
					s.sync;
				});
			};

			"Free Buffers".postln;

			if (newTempBuffers != nil, {
				newTempBuffers.do{|i| i.free};
				newTempBuffers = nil;
			});

			// Free buffers not in use.
	/*		newBufs[(cycleGenInd + 1) % ~sigBufRedundancy].do({ arg i;
				if(i != nil, {
					i.free;
					i = nil;
				});
			});*/

			s.sync;
			"New Buffers".postln;

			newTempBuffers = numNewIndividuals.collect{|i|
				var idx, newIndividual;
				idx = newGen[cycleGenInd].size - numNewIndividuals + i;
				newIndividual =  Buffer.loadCollection(s, newSigs[idx][0..~maximumSize]);
				s.sync;
				newIndividual;
			};

			"New temporary buffers: %".format(newTempBuffers).postln;

			newBufs[cycleGenInd] = newBufs[parentsGen] ++ newTempBuffers;

			// "New Buffers: %".format(newBufs[cycleGenInd]).postln;

			s.sync;

			if (envRecOn.not, {
				Routine{ 1.do {
					envRecOn = true;
					// "Recording environment on".postln;
					environment = ~recEnv.(envRecBuf, popOutputRecBuf, ~rfftParams[0], ~rfftParams[2], popIndex);
					(popOutputRecBuf.numFrames / s.sampleRate).wait;
					// "Recording environment off".postln;
					envRecOn = false;
				}}.play;
			});

			s.sync;

			// "Slice point generation".postln;

			newBufs[cycleGenInd].size.collect{|i|
				var slice, slicePoint;

				// "Index of slicing: %".format(i).postln;

				// Expand featureBuffers list if needed
				if (i >= featureBuffersGeno.size, {featureBuffersGeno.add(Buffer(s, numChannels: 1));
					spectralCentroidGeno.add(0);
					slicePointArray.add(0);
					s.sync;
				});

				// Identify slice points for measuring spectral centroid
				slice = newBufs[cycleGenInd][i].ampSlice(s, windowSize: 2048);

				// "Slice: %".format(slice).postln;

				// Store slicepoints for use in real-time centroid detection
				slice.get(1, {|msg|
					if (i >= slicePointArray.size, {
						slicePointArray.add(msg.asInteger);
					}, {
						slicePointArray[i] = msg.asInteger;
					});
				});

				// "Slice array: %".format(slicePointArray[i]).postln;

				s.sync;

				FluidBufSpectralShape.processBlocking(s, newBufs[cycleGenInd][i], 0, slicePointArray[i], select: [\centroid], features: featureBuffersGeno[i], windowSize: 2048);

				s.sync;

				featureBuffersGeno[i].loadToFloatArray(action: {|array| spectralCentroidGeno[i] = array.asArray.mean});
				s.sync;
			};

			if (0.5.coin, {
				"New convolution spectrum".postln;
				pebble = ~xFadeFbConvolve.(newBufs[cycleGenInd], feedbackSynths, ~convolveFftsize, pebble, 2, popIndex);
				"Pebble %".format(pebble).postln;
			});

			s.sync;

			"Play new buffers".postln;

			~playBufs.(popIndex, newBufs[cycleGenInd], slicePointArray, popIndex);

			// 5.0.wait;

			// "Update spectral features";

			// Update spectral features of each individual
			newBufs[cycleGenInd].size.do({|i|
				if(i < spectralCentroidDevPheno.size, {
					spectralCentroidDevPheno[i] = ~specCentAvgBus[popIndex][i].getSynchronous},{
					spectralCentroidDevPheno.add(~specCentAvgBus[popIndex][i].getSynchronous)
				});
			});

			genCounter = genCounter + 1;

			s.sync;

			};

	});
	};
	