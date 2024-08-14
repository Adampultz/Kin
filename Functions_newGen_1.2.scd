// Iterative function for slicing an ir buffer into a chosen number of segments. Works by iteratively lowering the threshold of the Novelty Slice function.
~ampSlice = {|buffer|
	var indices, slice, threshold = 0.6;
	indices = Buffer(s, 1);
	s.sync;
	slice = {|buffer|
		if(indices.numFrames <= 1, {
			threshold = threshold - 0.05;
			FluidBufNoveltySlice.processBlocking(s, buffer, indices: indices, algorithm: 0, kernelSize: 5, threshold: threshold,
				minSliceLength: 6, windowSize: 2048);
			s.sync;
			slice.(buffer);
		}
		);
	};
	slice.(buffer);
	indices;
};

// Calculate the next power of two of the buffer size, rfftsize, and a cosine table for rfft and irfft transform
~rfftInfo = {|bufferSize|
	var pow2, rfftSize, cosTable;
	pow2 = bufferSize.nextPowerOfTwo;
	rfftSize = (pow2 / 2 + 1).asInteger;
	cosTable = Signal.rfftCosTable(rfftSize);
	[pow2, rfftSize, cosTable];
};

// Generate the frequency response of the impulse response
~freqResponse = {|objectResponse, pow2, cosTable|
	var object, complex;

	// Zero-padding
	object = objectResponse.addAll(Array.fill(pow2 - objectResponse.size, {0}));

	object.discardDC; // DC offset
	object.normalizeMagnitude;

	complex = rfft(object, cosTable);

	complex;

};

// Crossover function for EA. Uses the Bark scale. First a random discrete section of the bark scale is chosen, and then a random point in that section. Crossover happens in both the real and imaginary value arrays. TODO: try doing crossover on rho in the polar representation (no theta).
~crossover = {|parents, size|
	var xOverPoint, xOverPoint_m1, size_m1, xOverArray, newInd, temparray, barkIndex;
	temparray = 2.collect{2.collect{2.collect{}}};
	barkIndex = (~barkScale.size - 1).rand;
	xOverPoint = ((~barkScale[barkIndex] + ~barkScaleCells[barkIndex].rand) * ~freqResolution).asInteger;
	xOverPoint_m1 = xOverPoint - 1;
	size_m1 = size - 1;
	xOverArray = [0, xOverPoint_m1, xOverPoint, size_m1];

	(parents.size).collect{|idx| // Iterate over parents
		var complexArray = [parents[idx].real, parents[idx].imag];

		[[0, 1], [2, 3]].do{|i, n| // Iterate over crossover array
			2.do{|complId|
				temparray[idx][n][complId] = complexArray[complId].copyRange(xOverArray[i[0]], xOverArray[i[1]]);
			};
		}
	};

	temparray;
};

~crossoverVertical = {|parents, size|
	var xOverPoint, newComplex, real, imag;
	/*	rand = exprand(0.001, 1.0);*/
	xOverPoint = 1.0.rand;

	real = (parents[0].real * xOverPoint) + (parents[1].real * (1.0 - xOverPoint));
	imag = (parents[0].imag * xOverPoint) + (parents[1].imag * (1.0 - xOverPoint));

	newComplex =real.as(Signal).complex(imag.as(Signal));
	// newComplex[idx].real.normalizeMagnitude;

	newComplex;
};

~crossoverVerticalPolar = {|parents, size|
	var xOverPoint, newComplex, polar, newPolar, zeroArray;
	xOverPoint = 1.0.rand;
	xOverPoint.postln;

	polar = (parents.size).collect{|idx|
		parents[idx].asPolar};

	zeroArray = size.collect{};
	newPolar = Polar(zeroArray, zeroArray);


	// Iterate over parents
	newPolar.rho = (polar[0].rho * xOverPoint) + (polar[1].rho * (1.0 - xOverPoint));
	newPolar.theta = (polar[0].theta * xOverPoint) + (polar[1].theta * (1.0 - xOverPoint));

	newComplex = newPolar.polarToComplexSignal;
	newComplex;
};

// Frequency spectrum envelope for attenuating high frequencies
~fftEnv = {|hiPass, loPass, curve, size|
	var lo, high, sustain, env;
	lo = hiPass / ~nyquist;
	high = 1 - (loPass / ~nyquist);
	sustain = 1 - (lo + high);

	env = Env([0,1,1,0], [lo, sustain, high], curve).asSignal(size);
};

// Combine two parents. Combines the lower spectrum of each with the upper spectrum of the other. Consider introducing a probabilty of flipping high and low spectrums. ToDO: remove rfft argument
~combine2 = {|newPop|
	var idx = 0;
	var popSize = newPop.size;
	var newInd = popSize.collect{2.collect{}};
	var newComplex;


	popSize.collect{|ind|
		var nextInd = (ind + 1) % 2;
		2.collect{|compl| // Iterate over complex and real values
			newInd[idx][compl] = newPop[ind][0][compl] ++ newPop[nextInd][1][compl];
		};
		idx = idx + 1;
	};

	newComplex = popSize.collect{|ind|
		newInd[ind][0].complex(newInd[ind][1])
	};

	newComplex;
};


~combine1 = {|newPop|
	var newInd = 2.collect{};
	var newComplex;
	var first = 2.rand;
	var second = (first + 1) % 2;


	2.collect{|compl| // Iterate over complex and real values
		newInd[compl] = newPop[first][0][compl] ++ newPop[second][1][compl];
	};

	newComplex = newInd[0].complex(newInd[1]);

	newComplex;
};

// Irfft with audio envelope to create a more impulse-like amplitude curve (in case there's artefacts in the ir tail)
~newGeneration = {|item, cosTable, audioEnv|
	(item.real.irfft(item.imag, cosTable) * audioEnv).normalize;
};

~newGenerationArray = {|array, cosTable, audioEnv|
	var y;
	array.size.collect{|i|
		(array[i].real.irfft(array[i].imag, cosTable) * audioEnv).normalize;
	};
};


// Inserts a selection of the spectrum of the environment into an individual.
~insertEnvSpectrum = {|indSpectrum, envSpectrum, width|
	var barkIndex, startFreq, barkWidth, envSelection, range = 2.collect{}, polarEnv, polarInd, newComplex, spectrumMeanRho;

	barkIndex = (~barkScale.size - 1).rand;
	startFreq = ~barkScale[barkIndex];
	barkWidth = (~barkScaleCells[barkIndex] * width).asInteger;
	range[0] = (((~barkScaleCells[barkIndex]).rand + startFreq) * ~freqResolution).round.asInteger;
	range[1] = (range[0] + (barkWidth * ~freqResolution)).round.asInteger;

	polarEnv = envSpectrum.asPolar.rho[range[0]..range[1]];

	polarInd = indSpectrum.asPolar;

	spectrumMeanRho = polarInd.rho[range[0]..range[1]].mean;

	polarEnv.do{|i, idx|
		polarInd.rho[range[0] + idx] = i + spectrumMeanRho};

	newComplex = polarInd.polarToComplexSignal
};

// Inserts a selection of the time-domain audio into the rho of an individual, retaining phase.
~insertEnvAudio = {|indSpectrum, envBuffer, width|
	var audioSize, spectrumSize, sizeRatio, audioRange, envAudio, barkIndex, startFreq, barkWidth, endFreq, envSelection, range = 2.collect{}, polarInd, newComplex, window, spectrumMeanRho;

	audioSize = envBuffer.numFrames;
	spectrumSize = indSpectrum.real.size;
	sizeRatio = spectrumSize / audioSize;
	barkIndex = (~barkScale.size - 1).rand;
	startFreq = ~barkScale[barkIndex];
	barkWidth = (~barkScaleCells[barkIndex] * width).asInteger;
	range[0] = (((~barkScaleCells[barkIndex]).rand + startFreq) * ~freqResolution).round.asInteger;
	range[1] = (range[0] + (barkWidth * ~freqResolution)).round.asInteger;
	audioRange = (range * sizeRatio).asInteger;

	envBuffer.normalize.loadToFloatArray(action: {|array|
		envAudio = array[audioRange[0]..audioRange[1]].abs.copy;
	});

	s.sync;

	window = Signal.hanningWindow(envAudio.size).asArray; // Creates a Hanning envelope for the Freqeuncy window that is being mutated

	polarInd = indSpectrum.asPolar;

	spectrumMeanRho = polarInd.rho[range[0]..range[1]].mean;

	envAudio.do{|i, idx|
		var val = polarInd.rho[range[0] + idx];
		polarInd.rho[range[0] + idx] = i + spectrumMeanRho;
	};

	newComplex = polarInd.polarToComplexSignal;
};


// Old code not in use. generate if from fr
~impResponse = {|freqResponse, cosTable, env|
	var ifft, curve;

	ifft * env;

	s.sync;

	Buffer.loadCollection(s, (ifft)).normalize
};

// // Generate random numbers without repetition
~randIntNoRep = { |n=8, min=0, max=7| (min..max).scramble.keep(n) };

// make array of randomly selected couples. TODO: make more efficient
~couples = {|popSize, numCouples|
	var a, b, array;

	array = (popSize - 1).collect{|i|
		(popSize - 1 - i).collect{|n|
			[i, i + (n + 1)]
		};
	};

	array = array.flatten;

	a = Array.randNoRep(numCouples, 0, array.size - 1);

	a.size.collect{|i|
		array[a[i]]
	};
};

// Encapsulates crossover and recombination
~newPop = {|population, rfftSize, parents|
	var popSize, couples, xOver, combine;
	popSize = population.size;
	couples = [population[parents[0]], population[parents[1]]];

	xOver = ~crossover.(couples, rfftSize);
	combine = ~combine1.(xOver);

	combine;
};

// Calculates the spectral centroid of an entire spectrum
~specCentroid = {|array|
	var mag, arraySize, steps, freqsNorm, centroid;
	mag = array.magnitude;
	arraySize = mag.size;
	steps = 1.0 / arraySize;
	freqsNorm = Array.fill(arraySize, {|i| i * steps});
	centroid = (freqsNorm * mag.normalizeSum).sum * ~nyquist;
};

// Calculates the distance of each item to the maximum value of the array
~distanceBelow = {|array|
	var meanVal, distances, arrayMax;
	arrayMax = array.maxItem;

	distances = array.size.collect{|i|
		var distance;
		distance = arrayMax - array[i];
	};

	distances.normalizeSum;
};

// Returns deviations, variance, and standard deviation
~stats = {|array|
	var mean, dev, variance, sd;
	mean = array.mean;
	dev = array.size.collect{|i| (array[i] - mean).pow(2)};
	variance = dev.sum / array.size;
	sd = variance.sqrt;
	[(dev / dev.sum).normalizeSum, variance, sd];
};

// Returns an estimate of the room impulse response, based on synchronised recording of the room and the output of the algorithm
// Also returns the room frequency response

~recEnv = {|envRecBuf, popRecBuf, pow2, cosineTable|
	var recSynth, freqRespEnv, freqRespPop, roomFreqResp, roomImpResp, envRecBufSignal, popRecSignal;

	recSynth = Synth(\rec, [\envBuf, envRecBuf, \popBuf, popRecBuf], target: ~mixerGrp);

	((envRecBuf.numFrames / s.sampleRate) + 0.5).wait;

	envRecBuf.loadToFloatArray(action: {|array|
		envRecBufSignal = array.as(Signal);
	});

	popRecBuf.loadToFloatArray(action: {|array|
		popRecSignal = array.as(Signal);
	});

	freqRespEnv = ~freqResponse.(envRecBufSignal, pow2, cosineTable);

	freqRespPop = ~freqResponse.(popRecSignal, pow2, cosineTable);

	roomFreqResp = freqRespEnv / freqRespPop;

	roomImpResp = Buffer.loadCollection(s, roomFreqResp.real.irfft(roomFreqResp.imag, cosineTable).normalize);

	s.sync;

	[roomImpResp, freqRespEnv];

};

// A weighted probabilistic number generators with no repetitions
~wchooseNorepeat = {|weights, numChoices = 4|
	var choices, indexes;
	indexes = Array.fill(weights.size, {|i| i});
	choices = numChoices.collect{|i|
		var selection = indexes.wchoose(weights.normalizeSum);
		weights.remove(weights[indexes.indexOf(selection)]);
		indexes.remove(selection);
		selection;
	};
	choices
};

~mutationRho = {|individual, width = 1|
	var polar, window, negWindow, globalRhoMax, centreFreq, windowGain, winRhoMax = 0, barkIndex, maxRealGain, fftWinSize, newComplex, fftWidth, fftWidthHalf;
	polar = individual.asPolar;
	globalRhoMax = polar.rho[polar.rho.maxIndex]; // Get value of peak rho
	barkIndex = (~barkScale.size - 1).rand;
	fftWidth = (~barkScaleCells[barkIndex] * width * ~freqResolution).asInteger;
	fftWidthHalf = (fftWidth / 2).asInteger;
	window = Signal.hanningWindow(fftWidth).asArray; // Creates a Hanning envelope for the Freqeuncy window that is being mutated
	negWindow = 1 - window;

	// "Bark Index: %".format(barkIndex).postln;
	centreFreq = ((~barkScale[barkIndex] + ~barkScaleCells[barkIndex].rand) * ~freqResolution).asInteger;
	centreFreq = centreFreq.clip(fftWidthHalf, polar.rho.size - fftWidthHalf);
	// "Centre freq: %".format(centreFreq).postln;
	// "Mutation frequency range: %".format([(centreFreq - fftWidthHalf), centreFreq, centreFreq + (fftWidthHalf - 1)]).postln;

	// Get the local maximum of the frequency window
	fftWidth.asInteger.collect{|n|
		var idx, valRho;
		idx = centreFreq - fftWidthHalf + n;
		valRho = polar.rho[idx];

		if(valRho > winRhoMax, {
			winRhoMax = valRho;
		});
	};

	maxRealGain = (globalRhoMax / winRhoMax) / 2; // Subtract the local maximum value from the global maximum value
	window = 1 + (window * maxRealGain * ~mutationCoeff);

	if (0.5.coin == true, {
		fftWidth.collect{|n|
			var idx, valRho, gainModifier;
			idx = centreFreq - fftWidthHalf + n;
			valRho = polar.rho[idx] * window[n];
			polar.rho[idx] = valRho;
		};
	}, {
		fftWidth.collect{|n|
			var idx, valRho, gainModifier;
			idx = centreFreq - fftWidthHalf + n;
			valRho = polar.rho[idx] * negWindow[n];
			polar.rho[idx] = valRho;
		};
		"negative mutation".postln;
	});

	newComplex = polar.polarToComplexSignal;

};

/*~geneSteal =

~geneSwap =*/

// Zero the phase. Doesn't seem to work properly. Look at linear phase
~zeroPhase = {|item|
	var polar, newComplex, size;
	size = item.real.size;
	polar = item.asPolar;

	size.do{|i|
		polar.theta[i] = 0.0};

	newComplex = polar.polarToComplexSignal
};

~counter = {
	var counter = ~pebble + 1;
	counter % 2 };

// For multiplying two spectrums. TODO: multiply polar
~multiplyComplex = {|items|
	var newItem = Signal.newClear(items[0].size).asComplex;
	newItem.real = items[0].real * items[1].real;
	newItem.imag = items[0].imag * items[1].imag;

	newItem;
};

~multiplyPolar = {|items|
	var polar, polarRho, polarTheta, newComplex;
	polarRho = (items[0].asPolar.rho * items[1].asPolar.rho).normalize(0, 1.0);
	polarTheta = items[0].asPolar.theta * items[1].asPolar.theta;
	polar = Polar(polarRho, polarTheta);
	newComplex = polar.polarToComplexSignal;
	newComplex;
};

~prepConvolve = {|buffer, fftSize|
	var bufSize, spectrum;
	bufSize = PartConv.calcBufSize(fftSize, buffer);
	spectrum = Buffer.alloc(s, bufSize, 1);
	spectrum.preparePartConv(buffer.normalize, fftSize);
	s.sync;
	spectrum;
};

// UGen for playing new irs.
SynthDef(\bufPlay,
	{|buf, panPos, index, slicePoint, envirSpectralShape, specCentAvgBus, envCentAvgBus, distanceBus, mixerBus, nyquist, volume, windowSize|
		var source, spectralShape, spectralShapeAvg, distance, averageTrig, specCentAvg, envSpecCentroidBus, envSpecCentroidAvgBus;
		source = PlayBuf.ar(1, buf, doneAction: 2);
		envSpecCentroidBus = In.kr(envirSpectralShape); // Spectral centroid measured by microphones
		envSpecCentroidAvgBus = In.kr(envCentAvgBus);
		spectralShape = FluidSpectralShape.kr(source, select: [\centroid], windowSize: windowSize);
		// Average the difference between the environments spectral centroid and the ir spectral centroid over 1-second windows
		distance = AverageOutput.kr(((spectralShape - envSpecCentroidBus) / nyquist).clip(-1.0, 1.0).squared, Impulse.kr(1));
		// Sample and hold the average of the distance between the spectral centroid of the individual to the environment (Average of 1 second);
		// In.kr(envCentAvgBus).poll;
		distance = Latch.kr(distance, DelayN.kr(Impulse.kr(0), 1, 1.0));
		// Sample and hold the difference between the average of a short(er) of the environment and the average of the last 10 seconds of the environment. Gives an estimate of the impulse responses impact on the environment. "slicepoint" refers to the slice point identified by running FluCoMa's novelty slicer on the spectrum of the ir buffer
		averageTrig = DelayN.kr(Impulse.kr(0), slicePoint, slicePoint);
		specCentAvg = AverageOutput.kr(envSpecCentroidBus, averageTrig);
		specCentAvg = Latch.kr(((specCentAvg - envSpecCentroidAvgBus) / nyquist).squared, averageTrig);
		source = Pan2.ar(source, panPos);
		Out.kr(specCentAvgBus, specCentAvg);
		// Out.kr(~specCentBus, spectralShapeAvg);
		Out.kr(distanceBus, distance);
		Out.ar(mixerBus, source * In.kr(volume))
}).add;


SynthDef(\mixer,
	{|buf, panPos|
		var source;
		source = In.ar(~mixerBus, 2);
		source = Limiter.ar(source, 0.9);
		Out.ar(~mainOut, (source * ~masterVol.kr));
		Out.ar(~toBlackhole, source);
}).add;

SynthDef(\soundIn,
	{
		var source, shapes, averageSpecCent;
		source = Mix(SoundIn.ar(~micInStereo));
		shapes = FluidSpectralShape.kr(source, [\centroid,\spread], windowSize: 2048);
		averageSpecCent = AverageOutput.kr(shapes[0], Impulse.kr(0.1));
		// shapes = OnePole.kr(shapes);
		Out.kr(~envCentAvg, averageSpecCent);
		Out.kr(~envCent, shapes[0]);
		Out.kr(~envSpread, shapes[1]);
}).add;

SynthDef(\feedBack,
	{|irBuffer, fftSize, fadeTime = 2, gate = 1|
		var source, convolution, out, amplitude, ampSel, env;
		source = SoundIn.ar(~micInStereo);
		amplitude = RMS.kr(source * 10, 10);
		env = EnvGen.kr(Env.asr(fadeTime, releaseTime: fadeTime), gate, doneAction: 2).sqrt;
		convolution = PartConv.ar(source, 4096, irBuffer);
		out = XFade2.ar(source, convolution, ~convolveMix.kr);
		Out.ar(~mixerBus, (out * ~feedbackVol.kr) * (1.0 - amplitude).clip(0.0, 1.0) * env);
}).add;

SynthDef(\rec,
	{| envBuf, popBuf|
		var phasor, env, sourceEnv, sourcePop, recPop, recEnv;
		phasor = Phasor.ar(0, BufRateScale.kr(envBuf), 0, BufFrames.kr(envBuf));
		env = EnvGen.kr(Env([0,1,1,0], [0.1, 0.8, 0.1], [-4, 1 ,4]), 1.0, timeScale: BufFrames.kr(envBuf) * SampleDur.ir, doneAction: 2);
		sourcePop = In.ar(~mixerBus, 2);
		sourceEnv = Mix(SoundIn.ar(~micInStereo));
		recPop = BufWr.ar(Mix(sourcePop) * env, popBuf, phasor, loop:0);
		recEnv = BufWr.ar(sourceEnv * env, envBuf, phasor, loop:0);
}).add;

~playBufs =  {|buffers, slicePoints|
	var size = buffers.size;
	var scrambleArray = Array.fill(size, {|i| i}).scramble;
	scrambleArray.do({|i|
		var waitTime = (1.0 / size).rrand(1.5);
		Synth(\bufPlay, [\buf, buffers[i], \panPos, -1.0.rrand(1.0), \slicePoint, slicePoints[i] / s.sampleRate, \specCentAvgBus, ~specCentAvgBus[i], \envCentAvgBus, ~envCentAvg, \envirSpectralShape, ~envCent, \distanceBus, ~distanceBus[i], \mixerBus, ~mixerBus, \nyquist, ~nyquist, \volume, ~irVolume, \windowSize, 2048], target: ~synthGrp);
		waitTime.wait;
	});
};


// Function for crossfading between feedback synths. Crossfade is needed when introducing a new buffer to PartConv. Uses a crude language-based counter with global variables (~pebble is there to keep maintain the counter outside of the function)
~xFadeFbConvolve = {|buffers, fftSize, fadeTime = 2|
	var buf, spectrum;
	buf = buffers.choose;
	spectrum = ~prepConvolve.(buf, 2048);
	s.sync;
	~feedbackSynths[~pebble].set(\gate, 0);
	~pebble = ~counter.();
	~feedbackSynths[~pebble] = Synth(\feedBack, [\irBuffer, spectrum.normalize, \fftSize, fftSize], target: ~convolveGrp);
};
