/* eff_flow.c — flow: comet with bright head, dim tail and a dark gap. */
#include "core.h"
#include "effects.h"

#include <stdio.h>

static void run(void);

const effect_t eff_flow = { "flow", "comet head + tapering 2-lamp tail + dark gap (60ms)", run };

/* contrast profile (user round 135+2): head 2x brightness, two-lamp dim tail,
 * THREE fully-dark lamps as separator — the dark gap is what makes the comet
 * read as motion instead of "everything slightly glowing". */
static const int PROF[RING_N] = { 3, 2, 1, 0, 0, 0 };

static void run(void) {
	fprintf(stderr, "ringlight: flow, 60ms/step, head=3 tail=2/1 gap=3\n");
	int codes[RING_N];
	int head = 0;
	while (!ringlight_should_stop()) {
		for (int i = 0; i < RING_N; i++)
			codes[i] = PROF[(head - i + RING_N) % RING_N];
		sinks_apply(codes);
		sleep_hybrid(now_us() + 60000LL);
		head = (head + 1) % RING_N;
	}
}
