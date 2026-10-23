package logview

import (
	"math"
	"strconv"
)

// ViewLimit is the size under which a file is displayed in the page (3 MiB, isFileTooLargeToBeViewed).
const ViewLimit = 3145728

// TooLargeToBeViewed reports whether a file of that size is too large to be viewed.
func TooLargeToBeViewed(size int64) bool { return size >= ViewLimit }

// HumanFilesize formats a size: the unit comes from the number of digits (1000-9999 bytes is "K"),
// so 1000 bytes shows "1000B"-style values like 0.98K; decimals digits after the point.
func HumanFilesize(bytes int64, decimals int) string {
	const sz = "BKMGTP"
	if bytes < 0 {
		bytes = 0
	}
	factor := (len(strconv.FormatInt(bytes, 10)) - 1) / 3
	if factor >= len(sz) {
		factor = len(sz) - 1
	}
	v := float64(bytes) / math.Pow(1024, float64(factor))
	p := math.Pow(10, float64(decimals))
	v = math.Round(v*p) / p // halves round up; Go's formatting would round them to even
	return strconv.FormatFloat(v, 'f', decimals, 64) + string(sz[factor])
}
