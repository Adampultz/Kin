~window = {
	var w, z;
	w = Window("Individuals", Rect(0, 0, 1500, 1000)).alwaysOnTop_(true).front;

~z = 2.collect{|i|
	var indent = 750 * i;
	CompositeView(
    w, Rect(indent, 10, 700, 1000)
);
};

	~a = 2.collect{|i| Plotter("Test %".format(i), parent: ~z[i]).superpose_(false)};
	/*a.plotColor_([Color.blue, Color.red])*/

};

~freqResponsevisualise = {|array|
	var arraySizeHalf = (array.size / 2).asInteger;
2.collect{|i|
		~a[i].value = arraySizeHalf.collect{|n|
			array[n + (arraySizeHalf * i)].magnitude};
		 ~a[i].domainSpecs_([20, 20000, \lin].asSpec);

	};

/*	~a.refresh;*/
};

~window.();
