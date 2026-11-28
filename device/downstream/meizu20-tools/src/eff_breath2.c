/* eff_breath2.c — alternating group breath (user round 135+2): lamps 1/3/5
 * and 2/4/6 breathe in ANTI-PHASE (180° offset). NOTE: interleaved adjacent
 * groups in anti-phase keep the ring TOTAL constant — the visible signal is
 * per-lamp CONTRAST, so the peak rides high (level 6 = 105.5mA vs floor
 * 17.6mA) to make the alternation read. Zero PWM; 32 samples x 50ms.
 */
#include "core.h"
#include "effects.h"

#include <stdio.h>

static void run(void);

const effect_t eff_breath2 = { "breath2", "1/3/5 ↔ 2/4/6 anti-phase breathing", run };

static void run(void) {
	const int peak_level = 6;
	const int sample_ms = 50;
	const int N = 32;

	int lvl[N]; /* sine ladder 1..peak */
	for (int i = 0; i < N; i++) {
		long long s = (long long)i * i * 100 / ((N - 1) * (N - 1));
		lvl[i] = 1 + (int)(((peak_level - 1) * s + 50) / 100);
	}
	fprintf(stderr, "ringlight: breath2 anti-phase %dx%dms peak=L%d\n", N, sample_ms, peak_level);

	int c[RING_N];
	long long k = 0;
	while (!ringlight_should_stop()) {
		long long p0 = now_us();
		/* sample index runs 0..2N-1 (up the ladder then down); group B is
		 * offset by N = 180 degrees */
		int idx = (int)(k % (2 * N));
		int a = lvl[idx < N ? idx : 2 * N - 1 - idx];
		int j = (idx + N) % (2 * N);
		int b = lvl[j < N ? j : 2 * N - 1 - j];
		for (int i = 0; i < RING_N; i++)
			c[i] = (i % 2 == 0) ? a : b; /* even lamps = 2/4/6, odd = 1/3/5 */
		sinks_apply(c);
		sleep_spin(p0 + sample_ms * 1000LL);
		k++;
	}
	sinks_clear();
}
