
var win, inChan, outChan, startFreq, endFreq, freqTextAnchor = [140, 150],
chanAnchor = [140, 70], inChanText, outChanText, genImpResp, saveImpresp, monitorResponse,
freqText = 2.collect{}, chanText = 2.collect{}, rountTripLatency, systemDelayText, fileNameText,
sweepTime, tail, sweepTimeText, tailText;

win = Window("Impulse response recording", Rect(128, 64, 800, 800));

fileNameText = TextField(win, Rect(10, 25, 600, 25));
fileNameText.string = "%".format(~name);
fileNameText.action = {|field|
	var date = Date.getDate.stamp.asString;
	~name = "%".format(field.value);
	~objName = ~name ++ "_%_%_%_%_%.wav".format("objectResponse", s.sampleRate, ~dur, ~roundTripLatency, date);
	~impulseName = ~name ++ "_%_%_%_%.wav".format("impulseResponse", s.sampleRate, ~dur, date);
	"Audio files will be saved with: %".format(~name).postln;
};

inChan = NumberBox(win, Rect(chanAnchor[0], chanAnchor[1], 60, 20));
inChan.value = ~inChan.getSynchronous.asInteger;
inChan.action = {|field| ~inChan.set(field.value.asInteger)};

outChan = NumberBox(win, Rect(chanAnchor[0], chanAnchor[1] + 30, 60, 20));
outChan.value = ~outChan.getSynchronous.asInteger;
outChan.action = {|field| ~outChan.set(field.value.asInteger)};

chanText[0] = StaticText(win, Rect(10, chanAnchor[1], 100, 20)).string = "Input Channel";
chanText[1] = StaticText(win, Rect(10,chanAnchor[1] + 30, 100, 20)).string = "Output Channel";

startFreq = NumberBox(win, Rect(freqTextAnchor[0], freqTextAnchor[1], 60, 20));
startFreq.value = ~startFreqBus.getSynchronous;
startFreq.action = {|text|
	~startFreqBus.set(text.value.asFloat);
	~sineChangeDetect = 1;
};
endFreq = NumberBox(win, Rect(freqTextAnchor[0], freqTextAnchor[1] + 30, 60, 20));
endFreq.value = ~endFreqBus.getSynchronous;
endFreq.action = {|field|
	~endFreqBus.set(field.value.asFloat);
	~sineChangeDetect = 1;
};

freqText[0] = StaticText(win, Rect(10, freqTextAnchor[1], 100, 20)).string = "Start Frequency";
freqText[1] = StaticText(win, Rect(10, freqTextAnchor[1] + 30, 100, 20)).string = "End Frequency";

sweepTime = NumberBox(win, Rect(140, 230, 60, 20));
sweepTime.value = ~recDur;
sweepTime.action = {|field|
	~recDur = field.value;
	~dur = ~recDur + ~tail;
	~sineChangeDetect = 1};

tail = NumberBox(win, Rect(140, 260, 60, 20));
tail.value = ~tail;
tail.action = {|field|
	~tail = field.value;
	~dur = ~recDur + ~tail;
	};

sweepTimeText = StaticText(win, Rect(10, 230, 100, 20)).string = "Sweep time";
tailText = StaticText(win, Rect(10, 260, 100, 20)).string = "Tail";


genImpResp = Button(win, Rect(250, 60, 100, 40))
.states_([
	["Play Sine", Color.black, Color.white]])
.mouseDownAction_({|val| ~playTestSignal.fork});

monitorResponse = Button(win, Rect(250, 120, 100, 40))
.states_([
	["Monitor Response", Color.black, Color.white]])
.mouseDownAction_({|val| ~objBuf.play});

monitorResponse = Button(win, Rect(250, 180, 100, 40))
.states_([
	["Monitor Impulse Response", Color.black, Color.white]])
.mouseDownAction_({|val| ~impResponseBuf.play});

saveImpresp = Button(win, Rect(250, 240, 100, 40))
.states_([
	["Save response", Color.black, Color.white]])
.mouseDownAction_({~writeAudioToDisk.fork});

systemDelayText = TextField(win, Rect(530, 60, 50, 40));
rountTripLatency = Button(win, Rect(380, 60, 130, 40))
.states_([
	["Get system delay", Color.black, Color.white]])
.mouseDownAction_({|val|
	~calcRTLatency.fork;
	{systemDelayText.string = "%".format(~roundTripLatency)}.defer(1.2)
});

~sfView = SoundFileView(win, Rect(10, 300, 600, 150));

~irView = SoundFileView(win, Rect(10, 550, 600, 150));


win.front;
win.alwaysOnTop = true;


