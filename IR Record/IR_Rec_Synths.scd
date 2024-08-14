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

		sine = PlayBuf.ar(1, buf);
		env0 = EnvGen.kr(Env([0, 1, 1, 0], [0.01, 0.98, 0.01], 'welch'), timeScale: recDur, doneAction: 2).scope;

		Out.ar(~outChan.kr, sine * 0.5 * env0)
}).add;

SynthDef(\rec,
	{|buf, run = 1, trig = 1, dur|
		var source, env;
		source = SoundIn.ar(~inChan.kr).scope;
		env = EnvGen.kr(Env([0, 1, 1, 0], [0.01, 0.89, 0.1], 'welch'), timeScale: dur, doneAction: 2);
		RecordBuf.ar(source * env, buf, run: run, loop: 0, trigger: trig);
}).add;