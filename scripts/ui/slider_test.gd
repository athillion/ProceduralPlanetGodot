extends HSlider

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	TestGlobals.slider = float(self.value) / 100.0
