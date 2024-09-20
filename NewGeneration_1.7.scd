s.options.memSize_(2.pow(20));
s.options.sampleRate_(48000);
s.options.numInputBusChannels_(6);
s.options.numOutputBusChannels_(40);
s.options.hardwareBufferSize = 128;
s.recHeaderFormat = "wav";
s.options.numBuffers = 4096;

s.options.outDevice_(
	// "MacBook Pro Speakers"
	// "External Headphones"
	// "ZoomAudioD"
	"Fireface UCX (23732049)"
	// "Fireface + Blackhole"
	// "Blackhole + Computer Audio"
	// "Fireface + Zoom"
	// "Zoom + Fireface"
	// "Scarlett 2i2 USB"
	//"Komplete Audio 6"
);

s.options.inDevice_(
	// "MacBook Pro Microphone"
	"Fireface UCX (23732049)"
	// "ZoomAudioD"
	// "Fireface + Blackhole"
	// "Blackhole + Computer Audio"
	// "Fireface + Zoom"
	// "Zoom + Fireface"
	// "Scarlett 2i2 USB"x
	//"Komplete Audio 6"
);

"Variables.scd".loadRelative;

MIDIIn.connectAll;

s.waitForBoot{

	~nyquist = s.sampleRate / 2;

	"Arrays.scd".loadRelative;

	~envGrp = Group.new;
	~synthGrp = Group.new(~envGrp, \addAfter);
	~convolveGrp = Group.new(~envGrp, \addAfter);
	~mixerGrp = Group.new(~synthGrp, \addAfter);

	"Busses.scd".loadRelative;

	s.sync;

	"Functions_newGen_1.2.scd".loadRelative;

	s.sync;

	/*~inSynth = Synth(\soundIn, target: ~envGrp);*/

	~objPath = "/Users/adammac2023/Documents/Musik-business/Adam/2024/Speculative Sound Synthesis/Code_27.07.2024/Impulse_responses/";

	~test = PathName(~objPath).files.do{|i|};

	~parentBuffers = ~test.size.collect{|i| Signal.read(~test[i].fullPath)};

	~maximumSize = ~parentBuffers.maxCollectionSize;

	~rfftParams = ~rfftInfo.(~maximumSize);

	~freqResolution = (((~rfftParams[1]).asInteger) / ~nyquist);

	~audioEnv = Env([0,1,1,0], [0.0, 0.9, 0.1], -4).asSignal(~maximumSize);

	~fourierEnv = ~fftEnv.(20, 20000, -4, ~rfftParams[1]);

	~parentFreqResp = ~parentBuffers.size.collect{|i|
		~freqResponse.(~parentBuffers[i], ~rfftParams[0], ~rfftParams[2]);
	};

	~parentFreqResp.do{|i|
		i.real.normalizeMagnitude};

	~newSigs[0] = ~parentFreqResp.size.collect{|i| ~newGeneration.(~parentFreqResp[i], ~rfftParams[2], ~audioEnv)};

	~newSigBufs = ~newSigs[0].size.collect{|i| Buffer.loadCollection(s, ~newSigs[0][i])};

	~parentIRs = ~newSigBufs.deepCopy;

	s.sync;

	/*~convolveSpectrum = ~prepConvolve.(~newSigBufs.choose, ~convolveFftsize);
	~convolveSpectrum = ~convolveSpectrum.normalize;*/

	s.sync;

	Synth(\mixer, [\amp, ~masterVol], target: ~mixerGrp);

	s.sync;

	"Populations.scd".loadRelative;
	"MIDI.scd".loadRelative;

	~makeControllers.();

	if (~visuals, {
		"Visualisation.scd".loadRelative;
		~freqResponsevisualise.(~parentFreqResp);
	});

	s.sync;

	"Initialise populations".postln;
	// Initialise the first and so far, only community
	~populations.(0, ~newSigs[0], ~parentFreqResp.asList);
	"One".postln;
	s.sync;
/*	~populations.(1, ~newSigs[0], ~parentFreqResp.asList);
	"Two".postln;
		s.sync;
	~populations.(2, ~newSigs[0], ~parentFreqResp.asList);
	"Three".postln;
		s.sync;
	~populations.(3, ~newSigs[0], ~parentFreqResp.asList);
	"Four".postln;*/

	"Done".postln;
	};
	