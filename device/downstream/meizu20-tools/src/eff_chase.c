/* eff_chase.c — chase: TWO symmetric (diametrically opposite) lamps, code 1,
 * stepping clockwise 120ms (user round 135+2: single-lamp chase -> pair). */
#include "core.h"
#include "effects.h"

#include <stdio.h>

static void run(void);

const effect_t eff_chase = { "chase", "one lamp steps clockwise (120ms)", run };

static void run(void) {
	fprintf(stderr, "ringlight: chase, symmetric pair, 120ms/step, code=1\n");
	int codes[RING_N];
	int pos = 0;
	while (!ringlight_should_stop()) {
		for (int i = 0; i < RING_N; i++)
			codes[i] = (i == pos || i == (pos + RING_N / 2) % RING_N) ? 1 : 0;
		sinks_apply(codes);
		sleep_hybrid(now_us() + 120000LL);
		pos = (pos + 1) % RING_N;
	}
}
