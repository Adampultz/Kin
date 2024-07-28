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

// Get the maximum buffer size of a collection. Useful for generating spectrums of the same size, regardless of ir lengths
~maxSize = {|array|
	var maxSize;
	maxSize = 0;

	array.do{|i|
		var objectBuffer, size;

		size = i.size;

		if(size > maxSize){
			maxSize = size;
		};
	};

	maxSize;
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

};

// Crossover function for EA. Uses the Bark scale. First a random discrete section of the bark scale is chosen, and then a random point in that section. Crossover happens in both the real and imaginary value arrays. TODO: try doing crossover on rho in the polar representation (no theta).
~crossover = {|parents, size|
	var rand, xOverPoint, xOverPoint_m1, size_m1, xOverArray, newInd, temparray, barkIndex;
	rand = exprand(0.001, 1.0);
	temparray = 2.collect{2.collect{2.collect{}}};
	// xOverPoint = (~freqResolution * 20000 * rand).asInteger;
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

// Frequency spectrum envelope for attenuating high frequencies
~fftEnv = {|hiPass, loPass, curve, size|
	var lo, high, sustain, env;
	lo = hiPass / ~nyquist;
	high = 1 - (loPass / ~nyquist);
	sustain = 1 - (lo + high);

	env = Env([0,1,1,0], [lo, sustain, high], curve).asSignal(size);
};

// Old version of combine
/*~combine = {|newPop, rfftSize|
	var idx = 0;
	var popSize = newPop.size;
	var newInd = (popSize * 2).collect{2.collect{}};
	var newComplex;
	/*/*	var idx = 0;*/
	var newPopCompl = newPop.size.collect{|i|
	2.collect{ |n|
	rfftSize.size}};*/

	popSize.collect{|ind|
		var nextInd = (ind + 1) % 2;
		2.collect{|xOver|
			var xOver_1 = (xOver + 1) % 2;
			2.collect{|compl|
				newInd[idx][compl] = newPop[ind][xOver][compl] ++ newPop[nextInd][xOver_1][compl];
			};
			idx = idx + 1;
		};
	};

	newComplex = (popSize * 2).collect{|ind|
		newInd[ind][0].complex(newInd[ind][1])
	};

	newComplex;
};*/

// Combine two parents. Combines the lower spectrum of each with the upper spectrum of the other. Consider introducing a probabilty of flipping high and low spectrums.
~combine2 = {|newPop, rfftSize|
	var idx = 0;
	var popSize = newPop.size;
	var newInd = (popSize).collect{2.collect{}};
	var newComplex;


	popSize.collect{|ind|
		var nextInd = (ind + 1) % 2;
		2.collect{|compl|
			newInd[idx][compl] = newPop[ind][0][compl] ++ newPop[nextInd][1][compl];
		};
		idx = idx + 1;
	};

	newComplex = (popSize).collect{|ind|
		newInd[ind][0].complex(newInd[ind][1])
	};

	newComplex;
};

// Irfft with audio envelope to create a more impulse-like amplitude curve (in case there's artefacts in the ir tail)
~newGeneration = {|item, cosTable, audioEnv|
	var y;
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
	var barkIndex, startFreq, barkWidth, endFreq, envSelection, range = 2.collect{}, polarEnv, polarInd, newComplex;

	barkIndex = (~barkScale.size - 1).rand;
	startFreq = ~barkScale[barkIndex];
	barkWidth = (~barkScaleCells[barkIndex] * width).asInteger;
	endFreq = ~barkScale[barkIndex + 1] - barkWidth;
	range[0] = (((~barkScaleCells[barkIndex] - barkWidth).rand + startFreq) * ~freqResolution).round.asInteger;
	range[1] = (range[0] + (barkWidth * ~freqResolution)).round.asInteger;

	polarEnv = envSpectrum.asPolar.rho[range[0]..range[1]];

	polarInd = indSpectrum.asPolar;

	polarEnv.do{|i, idx|
		polarInd.rho[range[0] + idx] = i};

	newComplex = polarInd.real.as(Signal).complex(polarInd.imag.as(Signal));
};


// Old code not in use. generate if from fr
~impResponse = {|freqResponse, cosTable, env|
	var ifft, curve;

	ifft * env;

	s.sync;

	Buffer.loadCollection(s, (ifft)).normalize
};

// Generate random numbers without repetition
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

	a = ~randIntNoRep.(numCouples, 0, array.size - 1);

	a.size.collect{|i|
		array[a[i]]
	};
};

// Encapsulates crossover and recombination
~newPop = {|population, rfftSize, parents, xOverProb|
	var popSize, couples, xOver, combine;
	popSize = population.size;
	couples = [population[parents[0]], population[parents[1]]];

	if (xOverProb.coin == true, {
		xOver = ~crossover.(couples, rfftSize);
		combine = ~combine2.(xOver);
	}, {
		// "No crossover".postln;
		combine = couples});

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

// Mutation. Needs work. Currently operating on the real and imaginary values. Will try with rho
~mutation = {|individual, which, width = 1|
	var window, realMax, imagMax, centreFreq, distribution, windowGain, winRealMax = 0, winImagMax = 0, maxRealGain, maxImagGain, realMean, imagMean, realImag, barkIndex;
	// window = ~hammingInv.(~freqResolution * width);
	window = (Signal.hanningWindow(~freqResolution * width));
	realMax = individual.real[individual.real.maxIndex];
	imagMax = individual.imag[individual.imag.maxIndex];
	realMean = individual.real.normalize.mean;
	imagMean = individual.imag.normalize.mean;
	/*		("Real max value of individual: %").format(realMax).postln;
	("Imaginary max value of individual: %").format(imagMax).postln;
	("Real mean value of individual: %").format(realMean).postln;
	("Imaginary mean value of individual: %").format(imagMean).postln;*/
	distribution = exprand(0.001, 1.0);
	// windowGain = (1.0 - distribution);
	// centreFreq = (~freqResolution) * (distribution * 20000).asInteger;
	barkIndex = (~barkScale.size - 1).rand;
	centreFreq = (~barkScale[barkIndex] + ~barkScaleCells[barkIndex].rand) * ~freqResolution;
	"Mutation centre frequency: %".format(centreFreq / ~freqResolution).postln;

	(~freqResolution * width).asInteger.collect{|n|
		var idx, valReal, valImag;
		idx = (centreFreq - ((~freqResolution * width) / 2).asInteger) + n;
		valReal = individual.real[idx];
		valImag = individual.imag[idx];

		if(valReal > winRealMax, {
			winRealMax = valReal;
		});

		if(valImag > winImagMax, {
			winImagMax = valReal;
		});
	};

	/*		("Real max value of window: %").format(winRealMax).postln;
	("Imaginary max value of window: %").format(winImagMax).postln;
	*/
	if(winRealMax != 0,{
		maxRealGain = (realMax / (winRealMax * 2));
		maxImagGain = (imagMax / (winImagMax * 2));

		if(winImagMax == 0,{
			maxImagGain = 1;
		});
	},{
		maxRealGain = 1;
		maxImagGain = 1;
	});

	/*	if(winImagMax != 0,{
	maxImagGain = imagMax / (winImagMax * 2)},{
	maxImagGain = 0;
	});*/
	//
	// "Max real: %".format(realMax).postln;
	// "Max imaginary: %".format(imagMax).postln;
	// "Max real Window: %".format(winRealMax).postln;
	// "Max imaginary Window: %".format(winImagMax).postln;

	// "Max real Gain: %".format(maxRealGain).postln;
	// "Max imaginary Gain: %".format(maxImagGain).postln;

	(~freqResolution * width).asInteger.collect{|n|
		var idx, valReal, valImag, gainModifier;
		gainModifier = 3;
		idx = (centreFreq - ((~freqResolution * width) / 2)).asInteger + n;
		/*	valReal = individual.real[idx] * (window[n] * ((maxRealGain.abs) * gainModifier));
		valImag = individual.imag[idx] * (window[n] * ((maxRealGain.abs) * gainModifier));*/
		valReal = individual.real[idx] * ((1 + window[n]) * gainModifier);
		valImag = individual.imag[idx] * ((1 + window[n]) * gainModifier);
		individual.real[idx] = valReal;
		individual.imag[idx] = valImag;
	};
};

~mutationRho = {|individual width = 1|
var polar, window, globalRhoMax, imagMax, centreFreq, windowGain, winRhoMax = 0, maxRealGain, maxImagGain, realMean, imagMean, realImag, barkIndex, fftWinSize;
	fftWinSize = ~freqResolution * width;
polar = individual.asPolar;
// window = ~hammingInv.(~freqResolution * width);
window = (Signal.hanningWindow(fftWinSize)); // Creates a Hanning envelope for the Freqeuncy window that is being mutated
globalRhoMax = polar.rho[polar.rho.maxIndex]; // Get value of peak rho
/*		("Real max value of individual: %").format(realMax).postln;
("Imaginary max value of individual: %").format(imagMax).postln;
("Real mean value of individual: %").format(realMean).postln;
("Imaginary mean value of individual: %").format(imagMean).postln;*/
// windowGain = (1.0 - distribution);
// centreFreq = (~freqResolution) * (distribution * 20000).asInteger;
barkIndex = (~barkScale.size - 1).rand;
centreFreq = (~barkScale[barkIndex] + ~barkScaleCells[barkIndex].rand) * ~freqResolution;
"Mutation centre frequency: %".format(centreFreq / ~freqResolution).postln;

// Get the local maximum of the frequency window
fftWinSize.asInteger.collect{|n|
var idx, valRho;
idx = (centreFreq - (fftWinSize / 2).asInteger) + n;
valRho = individual.real[idx];

if(valRho > winRhoMax, {
winRhoMax = valRho;
});

};

/*		("Real max value of window: %").format(winRealMax).postln;
("Imaginary max value of window: %").format(winImagMax).postln;
*/

maxRealGain = globalRhoMax - winRhoMax; // Subtract the local maximum value from the global maximum value
window = (window + 1) * maxRealGain * 0.5;

/*	if(winImagMax != 0,{
maxImagGain = imagMax / (winImagMax * 2)},{
maxImagGain = 0;
});*/
//
// "Max real: %".format(realMax).postln;
// "Max imaginary: %".format(imagMax).postln;
// "Max real Window: %".format(winRealMax).postln;
// "Max imaginary Window: %".format(winImagMax).postln;

// "Max real Gain: %".format(maxRealGain).postln;
// "Max imaginary Gain: %".format(maxImagGain).postln;

fftWinSize.asInteger.collect{|n|
var idx, valReal, valImag, gainModifier;
gainModifier = 3;
idx = (centreFreq - (fftWinSize / 2)).asInteger + n;
/*	valReal = individual.real[idx] * (window[n] * ((maxRealGain.abs) * gainModifier));
valImag = individual.imag[idx] * (window[n] * ((maxRealGain.abs) * gainModifier));*/
valReal = individual.real[idx] * ((1 + window[n]) * gainModifier);
valImag = individual.imag[idx] * ((1 + window[n]) * gainModifier);
individual.real[idx] = valReal;
individual.imag[idx] = valImag;
};
};

// Zero the phase. Doesn't seem to work properly. Look at linear phase
~zeroPhase = {|item|
	var polar, newComplex, size;
	size = item.real.size;
	polar = item.asPolar;

	size.do{|i|
		polar.theta[i] = 0.0};

	newComplex = polar.real.as(Signal).complex(polar.imag.as(Signal));
};

~counter = {
	var counter = ~pebble + 1;
	counter % 2 };

// For multiplying two spectrums
~multiplyComplex = {|items|
	var newItem = Signal.newClear(items[0].size).asComplex;
	newItem.real = items[0].real * items[1].real;
	newItem.imag = items[0].imag * items[1].imag;

	newItem;
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
50.collect{|i|
	SynthDef("bufPlay_%".format(i),
		{|buf, panPos, index, slicePoint|
			var source, spectralShape, spectralShapeAvg, envirSpectralShape, distance, averageTrig, specCentAvg;
			source = PlayBuf.ar(1, buf, doneAction: 2);
			envirSpectralShape = ~envCent.kr;
			spectralShape = FluidSpectralShape.kr(source, select: [\centroid], windowSize: 2048);
			// Average the difference between the environments spectral centroid and the ir spectral centroid over 1-second windows
			distance = AverageOutput.kr(((spectralShape - envirSpectralShape) / ~nyquist).clip(-1.0, 1.0).squared, Impulse.kr(1));
			// Sample and hold the average of the distance between the spectral centroid of the individual to the environment (Average of 1 second);
			distance = Latch.kr(distance, DelayN.ar(Impulse.kr(0), 1, 1.0));


			// Sample and hold the difference between the average of a short(er) of the environment and the average of the last 10 seconds of the environment. Gives an estimate of the impulse responses impact on the environment. "slicepoint" refers to the slice point identified by running FluCoMa's novelty slicer on the spectrum of the ir buffer
			averageTrig = DelayN.ar(Impulse.kr(0), slicePoint, slicePoint);
			specCentAvg = AverageOutput.kr(envirSpectralShape, averageTrig);
			specCentAvg = Latch.kr(((specCentAvg - ~envCentAvg.kr) / ~nyquist).squared, averageTrig);
			source = Pan2.ar(source, panPos);
			Out.kr(~specCentAvgBus[i], specCentAvg);
			// Out.kr(~specCentBus, spectralShapeAvg);
			Out.kr(~distanceBus[i], distance);
			Out.ar(~mixerBus, source * ~irVolume.kr)
	}).add;
};

SynthDef(\mixer,
	{|buf, panPos|
		var source;
		source = In.ar(~mixerBus, 2);
		Out.ar(~mainOut, (source * ~masterVol.kr));
		/*		Out.ar(~toBlackhole, source);*/
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
		convolution = PartConv.ar(source, 4096, irBuffer).scope;
		out = XFade2.ar(source, convolution, ~convolveMix.kr);
		Out.ar(~mixerBus, (out * ~feedbackVol.kr.scope) * (1.0 - amplitude).clip(0.0, 1.0) * env.scope);
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
	buffers.do({|i, idx|
		var size = buffers.size;
		var waitTime = (1.0 / size).rrand(1.5);
		Synth("bufPlay_%".format(idx).format(idx), [\buf, i, \panPos, -1.0.rrand(1.0), \slicePoint, slicePoints[idx] / s.sampleRate, \index, idx], target: ~synthGrp);
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
	~pebble.postln;
	~feedbackSynths[~pebble] = Synth(\feedBack, [\irBuffer, spectrum.normalize, \fftSize, fftSize], target: ~convolveGrp);
};
