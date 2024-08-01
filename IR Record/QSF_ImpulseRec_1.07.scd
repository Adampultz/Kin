s.plotTree;

(
s.options.sampleRate_(48000);
s.options.numInputBusChannels_(6);
s.options.numOutputBusChannels_(6);
s.options.hardwareBufferSize = 64;
s.recHeaderFormat = "wav";

s.options.outDevice_(
	 //"Built-in Output"
   "Fireface UCX (23732049)"
	// "Scarlett 2i2 USB"
	//"Komplete Audio 6"
);

s.options.inDevice_(
	"Fireface UCX (23732049)"
	// "Scarlett 2i2 USB"x
	//"Komplete Audio 6"
);

~recDur = 5.0;
~tail = 4;
~waitTime = 1;
~dur = ~recDur + ~tail;

~name = "Write object name here";
~objName = ~name ++ "_%_%_env".format(48000, ~dur);
~impulseName = ~name ++ "_%_%_%".format(48000, ~dur, "impulseResponse");
~sineName = "SineExpGuiTest_%_%_env".format(48000, ~dur);

~writePath = "/Users/adammac2023/Documents/Musik-business/Projects/Queer Sonic Fingerprint/Audio/Impulse_Responses/Dahlem_16.06.2024/";

~sineBuf = Bus.audio(s);



~recPathObj = PathName(thisProcess.nowExecutingPath.dirname ++ "/TestAudio/");
~recPathSine = PathName(thisProcess.nowExecutingPath.dirname ++ "/TestAudio/");

~roundTripLatency = 0;

~sineChangeDetect = 0;

~calcRTLatency = {
1.0.wait;
x = Synth(\latency);

s.sync;

~latencyBuffer.loadToFloatArray(action: {arg array; ~latencyArray = array;});

s.sync;

{var max = 0.0, maxIdx;
~latencyArray.do{|i, idx|
	// i.postln;
	if(i > max, {
		max = i;
		maxIdx = idx;
});
		};
		s.sync;
		~roundTripLatency = maxIdx;
		"Round trip latency = % samples".format(maxIdx).postln;
}.fork;
};

~generateImpResponse = {|testSig, testResponse|
	var prepObj, prepSine, fftInfo, freqRespObj, freqRespSine, division;

	prepObj = ~prepareObj.(testResponse, ~roundTripLatency);
	prepSine = ~prepareSine.(testSig);

	fftInfo = ~rfftSize.(prepObj.size);

	freqRespObj = ~freqResponseObj.(prepObj, fftInfo);
	freqRespSine = ~freqResponseObj.(prepSine, fftInfo);

	division = freqRespObj / freqRespSine;
	~impResponse.(division, fftInfo);
};

~writeAudioToDisk = {
	var time = Date.getDate.stamp;

	if(~impResponseBuf != nil,{
	~objBuf.write(~writePath ++ "Objects/%_%_%_%".format(~objName, ~roundTripLatency, time, ".wav") , "wav");

		// ~sineBuf.write(~writePath ++ "Sines/%_%".format(~sineName, ".wav"), "wav");

	~impResponseBuf.write(~writePath ++ "Impulse_Responses/%_%_%".format(~impulseName, time, ".wav"), "wav");
	}, {"Nothing has been recorded. Record something before writing to disk".postln});
};

s.waitForBoot({

~outChan = Bus.control(s).set(2);
~inChan = Bus.control(s).set(0);

~startFreqBus = Bus.control(s).set(20);
~endFreqBus = Bus.control(s).set(20000);

	// "QSF_Functions_SC_backup_26_04.scd".loadRelative;

~synthGrp = Group.new;
~recGrp = Group.new(~synthGrp, \addAfter);
~latencyBuffer = Buffer.alloc(s, s.sampleRate * 0.2);


	// ~latencyBuf = 2.collect{Buffer.alloc(s, s.sampleRate * 0.2)};

~objBuf = Buffer.alloc(s, s.sampleRate * ~dur);
~sineBuf = Buffer.alloc(s, s.sampleRate * ~recDur);

/*SynthDef(\impulse,
	{|out = 2|
		var in = SoundIn.ar(2);
		var impulse = Impulse.ar(0);
			// var recDirect = RecordBuf.ar(impulse, ~latencyBuf[1], loop: 0, doneAction: 2);
		var recReturn = RecordBuf.ar(impulse + in, ~latencyBuf[1], loop: 0, doneAction: 2);
		Out.ar(~outChan, impulse)
}).add;*/

/*	~playTestSignal = ({

	~waitTime.wait;

	x = Synth(\rec, target: ~recGrp);
	y = Synth(\sine, target: ~synthGrp);

	(~dur).wait;

	s.sync;

	~generateImpResponse.(~sineBuf, ~objBuf);

	s.sync;

	~objBuf.loadToFloatArray(action: {|array|
		{~sfView.setData(array, channels: 1, samplerate: s.sampleRate)}.defer});

	s.sync;

	~impResponseTest.loadToFloatArray(action: {|array|
		{~irView.setData(array, channels: 1, samplerate: s.sampleRate)}.defer});

	"Done".postln;

});*/

~playTestSignal = ({

	if(~sineChangeDetect != 0, {
		~expSineSweepBuffer = ~expSineSweep.(~startFreqBus.getSynchronous, ~endFreqBus.getSynchronous, ~recDur, s.sampleRate);
		s.sync;

		~objBuf = Buffer.alloc(s, s.sampleRate * ~dur);
		~sineBuf = Buffer.alloc(s, s.sampleRate * ~recDur);
		s.sync;
		});

		// s.sync;

	~waitTime.wait;

	Synth(\rec, [\buf, ~objBuf, \dur, ~dur], target: ~recGrp);
	Synth(\sine, [\buf, ~expSineSweepBuffer, \recDur, ~recDur], target: ~synthGrp);

	~dur.wait;

		// s.sync;

	~impResponseBuf = ~generateImpResponse.(~expSineSweepBuffer, ~objBuf);

	s.sync;

	 ~objBuf.loadToFloatArray(action: {|array|
			a = array;
	 {~sfView.setData(array, channels: 1, samplerate: s.sampleRate)}.defer});

		// {~sfView.setData(~objBuf, channels: 1, samplerate: s.sampleRate)}.defer;


	~impResponseBuf.loadToFloatArray(action: {|array|
			a = array;
	 {~irView.setData(array, channels: 1, samplerate: s.sampleRate.asInteger)}.defer});

	s.sync;

	~sineChangeDetect = 0;

	"Done".postln;

});

	~prepareSine = {|buffer|
	var sineReverseArray, sineArray;

	buffer.loadToFloatArray(action: {arg array; sineArray = array});
	s.sync;
	// sineReverseArray = sineArray.reverse;
	sineArray
};

	~expSineSweep = {|f1, f2, time, sRate|
		var sweepRate, array, sF, arrayLength, sine;
		sweepRate = log(f2/f1);
		sF = 1 / sRate;
		arrayLength = sRate * time;
		array = Array.fill(arrayLength, {|i| sF * i});
		sine = Array.fill(arrayLength, {|i|
			sin((2 * pi * f1 * (time / sweepRate)) * (exp(array[i] * sweepRate / time) -1))});
		Buffer.loadCollection(s, sine);
};
	s.sync;
	~expSineSweepBuffer = ~expSineSweep.(~startFreqBus.getSynchronous, ~endFreqBus.getSynchronous, ~recDur, s.sampleRate);
	s.sync;

		~prepareObj = {|buffer, rtLatency|
	var ltCorrArray, mean, bufArray, test, bufMean, env;

	buffer.loadToFloatArray(action: {arg array;
		bufArray = array;
	}); // Load buffer to array

	s.sync;

	ltCorrArray = bufArray[rtLatency..(bufArray.size - 1)]; //

	s.sync;

	ltCorrArray
};

	~rfftSize = {|bufferSize|
	var pow2, rfftSize, cosTable;
	pow2 = bufferSize.nextPowerOfTwo;
	rfftSize = (pow2 / 2 + 1).asInteger;
	cosTable = Signal.rfftCosTable(rfftSize);
	[pow2, rfftSize, cosTable];
};

	~freqResponseObj = {|objectResponse, fftInfo|
	var object, real, complex;

	real = Signal.newClear(fftInfo[0]);

	// Zero-padding
	object = objectResponse.addAll(Array.fill(fftInfo[0] - objectResponse.size, {0}));

	s.sync;

	object.do{|i, idx|
		real[idx] = i};

	real.discardDC;
	real.normalizeMagnitude;

	s.sync;

	complex = rfft(real, fftInfo[2]);
};

	~impResponse = {|freqResponse, fftInfo|
		var ifft, curve;

		// ifft = freqResponse.real.irfft(freqResponse.imag, cosineTable)[0..(~fftInfo[0] * 0.75).asInteger];
		ifft = freqResponse.real.irfft(freqResponse.imag, fftInfo[2]);

		ifft;
/*	curve = ~expCurve.(ifft.size, 0.5, 0.5);

	ifft = ifft.size.collect{|i|
		ifft[i] * curve[i]};*/

	 s.sync;

	Buffer.loadCollection(s, (ifft)).normalize
	};

SynthDef(\latency,
	{ var impulse, source;
		source = SoundIn.ar(~inChan.kr);
		impulse = Impulse.ar(0);
		RecordBuf.ar(source, ~latencyBuffer, loop: 0, doneAction: 2);
		Out.ar(~outChan.kr, impulse);
}).add;

SynthDef(\sine,
	{|run = 1, trig = 1, buf, recDur|
		var sine, env0;
			// sine = SinOsc.ar(XLine.kr(~startFreqBus.kr, ~endFreqBus.kr, ~recDur));

		sine = PlayBuf.ar(1, buf);
			env0 = EnvGen.kr(Env([0, 1, 1, 0], [0.01, 0.989, 0.001], 'welch'), timeScale: recDur, doneAction: 2).scope;
			// env1 = Line.ar(dur: ~dur, doneAction:2);
			// RecordBuf.ar(sine * env0, ~sineBuf, run: run, loop: 0, trigger: trig);
			// Out.ar(~sineBuf, sine * 0.5);
		Out.ar(~outChan.kr, sine * 0.5 * env0)
}).add;

SynthDef(\rec,
	{|buf, run = 1, trig = 1, dur|
		var source, env;
			source = SoundIn.ar(~inChan.kr).scope;
			env = EnvGen.kr(Env([0, 1, 1, 0], [0.01, 0.89, 0.1], 'welch'), timeScale: dur, doneAction: 2);
			RecordBuf.ar(source * env, buf, run: run, loop: 0, trigger: trig);
}).add;

s.sync;

	"impVisuals.scd".loadRelative;

});



);

~objBuf.free;

~objBuf = Buffer.alloc(s, s.sampleRate * ~dur);

~calcRTLatency.fork;


(
~playTestSignal = ({

	~waitTime.wait;

	x = Synth(\rec, target: ~recGrp);
	y = Synth(\sine, target: ~synthGrp);

	(~dur).wait;

	~generateImpResponse.(~sineBuf, ~objBuf);

	s.sync;

	 ~objBuf.loadToFloatArray(action: {|array|
	 {~sfView.setData(array, channels: 1, samplerate: s.sampleRate)}.defer});

	 s.sync;

	// ~impResponseTest.loadToFloatArray(action: {|array|
	// {~irView.setData(array, channels: 1, samplerate: s.sampleRate)}.defer});

	"Done".postln;

});
);

~playTestSignal.fork;

~sineBuf.plot
~objBuf.plot

~objBuf.play

~sineArray;

~sineBuf.loadToFloatArray(action: {|array| ~sineArray = array});

~sineArray[(~sineArray.size - 40)..(~sineArray.size - 1)].plot



~sineBuf.numFrames / 48000

~sineBuf.numFrames / 48000


~objBuf = Buffer.read(s, "/Users/adammac2023/Documents/Musik-business/Projects/Queer Sonic Fingerprint/Audio/Impulse_Responses/Object_Audio/KanteenGUiTest_di_48000_5.0.wav");


~sineBuf = Buffer.read(s, "/Users/adammac2023/Documents/Musik-business/Projects/Queer Sonic Fingerprint/Audio/Impulse_Responses/Object_Audio/SineExpGuiTest_48000_5.0_env.wav");




~writeAudioToDisk = {
	var time = Date.getDate.stamp;

	~objBuf.write("/Users/adammac2023/Documents/Musik-business/Projects/Queer Sonic Fingerprint/Audio/Impulse_Responses/Dahlem/Objects/%".format(~objName) , "wav");

~sineBuf.write("/Users/adammac2023/Documents/Musik-business/Projects/Queer Sonic Fingerprint/Audio/Impulse_Responses/Dahlem/Sines/%".format(~sineName) , "wav");

~impResponseTest.write("/Users/adammac2023/Documents/Musik-business/Projects/Queer Sonic Fingerprint/Audio/Impulse_Responses/Dahlem/Impulses/%".format(~impulseName) , "wav");
};

