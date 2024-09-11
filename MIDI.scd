/* Automatically detect MIDI controllers */

if (MIDIClient.sources.detect { |e| e.device.containsi("nanoKONTROL2") } != nil)
{
	~nanoKtl_source = MIDIClient.sources.detect { |e| e.device.containsi("nanoKONTROL2") }.uid;
} {
	~nanoKtl_source = nil};

~makeControllers = {

	// Channel 1

	MIDIFunc.cc({|val|
		~masterVol.set(val.linlin(0, 127, 0.0, 1.0));
	}, 0, 0,~nanoKtl_source);

	3.collect{|n|
	MIDIFunc.cc({|val|
		~feedbackVol[n].set(val.linlin(0, 127, 0.0, 1.0));
		}, 1 + (n * 2), 0,~nanoKtl_source);

	MIDIFunc.cc({|val|
		~irVolume[n].set(val.linlin(0, 127, 0.0, 1.0));
	}, 2 + (n * 2), 0,~nanoKtl_source);

	MIDIFunc.cc({|val|
		~convolveMix[n].set(val.linlin(0, 127, -1.0, 1.0));
	}, 17 + (n * 2), 0,~nanoKtl_source);
	}

};
