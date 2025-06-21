package main

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Cocoa
#include "region_select.h"
*/
import "C"

func SelectRegion() (x, y, w, h int) {
	region := C.select_region()
	return int(region.x), int(region.y), int(region.width), int(region.height)
}
