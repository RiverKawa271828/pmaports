/* eff_alternate.c — 1/3/5 ↔ 2/4/6 alternating blink (user round 135+2).
 * Neat hardware coincidence: lamps 1/3/5 = chip B, 2/4/6 = chip A, so each
 * phase is exactly one chip lit. Level 1 (17.6mA), 400ms per phase.
 */
#include "core.h"
#include "effects.h"

#include <stdio.h>

static void run(void);

const effect_t eff_alternate = { "alternate", "1/3/5 ↔ 2/4/6 alternating blink", run };

static void run(void) {
	const int level = 1;
	const int phase_ms = 400;
	fprintf(stderr, "ringlight: alternate level=%d phase=%dms\n", level, phase_ms);

	while (!ringlight_should_stop()) {
		int c[RING_N];
		for (int phase = 0; phase < 2 && !ringlight_should_stop(); phase++) {
			for (int i = 0; i < RING_N; i++)
				c[i] = ((i % 2) == phase) ? level : 0;
			sinks_apply(c);
			sleep_spin(now_us() + phase_ms * 1000LL);
		}
	}
	sinks_clear();
}
