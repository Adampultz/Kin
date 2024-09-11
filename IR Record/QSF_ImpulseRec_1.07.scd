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

~recDur = 7.0;
~tail = 4;
~waitTime = 1;
~dur = ~recDur + ~tail;

~name = "Write object name here";
~objName = ~name ++ "_%_%_env".format(s.sampleRate, ~dur);
~impulseName = ~name ++ "_%_%_%".format(s.sampleRate, ~dur, "impulseResponse");
~sineName = "SineExpGuiTest_%_%_env".format(s.sampleRate, ~dur);

~writePath = "/Users/adammac2023/Documents/Musik-business/Projects/Queer Sonic Fingerprint/Audio/Impulse_Responses/Naturkundemuseum/";

// ~writePath = "/Users/adammac2023/Documents/Musik-business/Adam/2024/Speculative Sound Synthesis/Audio";
~writePathFR = ~writePath ++  "Frequency responses/FR/";
~writePathIR = ~writePath ++ "IR";


~sineBuf = Bus.audio(s);

~recPathObj = PathName(thisProcess.nowExecutingPath.dirname ++ "/TestAudio/");
~recPathSine = PathName(thisProcess.nowExecutingPath.dirname ++ "/TestAudio/");

~roundTripLatency = 0;

~sineChangeDetect = 0;

s.waitForBoot({

~outChan = Bus.control(s).set(2);
~inChan = Bus.control(s).set(0);

~startFreqBus = Bus.control(s).set(20);
~endFreqBus = Bus.control(s).set(20000);

~synthGrp = Group.new;
~recGrp = Group.new(~synthGrp, \addAfter);
~latencyBuffer = Buffer.alloc(s, s.sampleRate * 0.2);

~objBuf = Buffer.alloc(s, s.sampleRate * ~dur);
~sineBuf = Buffer.alloc(s, s.sampleRate * ~recDur);

	"IR_Rec_Functions.scd".loadRelative;
	"IR_Rec_Synths.scd".loadRelative;

	s.sync;

	~expSineSweepBuffer = ~expSineSweep.(~startFreqBus.getSynchronous, ~endFreqBus.getSynchronous, ~recDur, s.sampleRate);

	s.sync;

	"impVisuals.scd".loadRelative;

});

)




