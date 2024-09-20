~barkScale = [20, 100, 200, 300, 400, 510, 630, 770, 920, 1080, 1270, 1480, 1720, 2000, 2320, 2700, 3150, 3700, 4400, 5300, 6400, 7700, 9500, 12000, 15500, 20500, ~nyquist.asInteger];

~barkScaleCells = (~barkScale.size - 1).collect{|i|
	~barkScale[i + 1] - ~barkScale[i];
};

~tasks = ~numPop.collect{};

~newGen = ~numEnvironments.collect{~ancestralMemory.collect{}};

~newSigs = ~numEnvironments.collect{~ancestralMemory.collect{}};

~testSpecArray = 8.collect{}.asList;

~variancePlot = List(0);
