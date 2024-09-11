// Busses for real-time control

~convolveMix = 4.collect{Bus.control(s).set(-1.0)}; // Wet-dry convolution mix. Convolution operates in the feedback chain. -1 = off, 1 = fully convolved. If using a nanoKontrol, mapped to dial 2

~feedbackVol = 4.collect{Bus.control(s)}; // 0 - 1. Controls the gain of the microphone. NanoKontrol: slider 2

~irVolume = 4.collect{Bus.control(s)}; // 0 - 1. Volume of the playback of the irs. NanoKontrol: slider 3

~masterVol = Bus.control(s); // 0 -1. Master volume. NanoKontrol: slider 1

// Analysis busses

~envCent = 4.collect{Bus.control(s)};

~envCentAvg = 4.collect{Bus.control(s)};

~envSpread = 4.collect{Bus.control(s)};

~distanceBus = 4.collect{100.collect{Bus.control(s)}};

~specCentAvgBus = 4.collect{100.collect{Bus.control(s)}};

// ~specCentBus = 50.collect{Bus.control(s)};

// Audio busses

~mixerBus = Bus.audio(s, numChannels: 2);
