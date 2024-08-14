// Busses for real-time control

~convolveMix = Bus.control(s).set(-1.0); // Wet-dry convolution mix. Convolution operates in the feedback chain. -1 = off, 1 = fully convolved. If using a nanoKontrol, mapped to dial 2

~feedbackVol = Bus.control(s); // 0 - 1. Controls the gain of the microphone. NanoKontrol: slider 2

~irVolume = Bus.control(s); // 0 - 1. Volume of the playback of the irs. NanoKontrol: slider 3

~masterVol = Bus.control(s); // 0 -1. Master volume. NanoKontrol: slider 1

// Analysis busses

~envCent = Bus.control(s);

~envCentAvg = Bus.control(s);

~envSpread = Bus.control(s);

~distanceBus = 100.collect{Bus.control(s)};

~specCentAvgBus = 100.collect{Bus.control(s)};

// ~specCentBus = 50.collect{Bus.control(s)};

// Audio busses

~mixerBus = Bus.audio(s, numChannels: 2);
