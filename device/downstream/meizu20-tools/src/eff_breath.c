/* eff_breath.c — v13: symmetric sine, peak capped at level 6 (105.5mA;
 * v12's peak 8 = 140.5mA read too bright — the smoothness comes from the 50ms
 * symmetric sampling, not from ladder length). 24 samples, 6 rungs.
 * Bottom = level 1 rest (17.6mA floor), NO dark phase.
 * No PWM anywhere; every frame is constant current.
 */
#include "core.h"
#include "effects.h"

#include <stdio.h>

static void run(void);

const effect_t eff_breath = { "breath", "all-lamp breathing, symmetric sine", run };

static void apply_level(int level) {
	int c[RING_N];
	for (int j = 0; j < RING_N; j++)
		c[j] = level;
	sinks_apply(c);
}

static void run(void) {
	const int peak_level = 6;   /* register 5 = 105.5mA apex */
	const int sample_ms = 40;   /* both directions */
	const int N = 24;
	const int peak_ms = 100;
	const int rest_ms = 200;    /* level-1 floor rest before next rise */

	int lvl[N];
	for (int i = 0; i < N; i++) {
		long long s = (long long)i * i * 100 / ((N - 1) * (N - 1));
		lvl[i] = 1 + (int)(((peak_level - 1) * s + 50) / 100);
	}
	int cycle = N * sample_ms * 2 + peak_ms + rest_ms;
	fprintf(stderr,
		"ringlight: breath v13 symmetric %dx%dms peak=L%d+%dms rest=%dms cycle=%dms\n",
		N, sample_ms, peak_level, peak_ms, rest_ms, cycle);

	while (!ringlight_should_stop()) {
		for (int i = 0; i < N && !ringlight_should_stop(); i++) { /* rise */
			apply_level(lvl[i]);
			sleep_spin(now_us() + sample_ms * 1000LL);
		}
		apply_level(peak_level); /* apex */
		sleep_spin(now_us() + peak_ms * 1000LL);
		for (int i = N - 1; i >= 0 && !ringlight_should_stop(); i--) { /* fall */
			apply_level(lvl[i]);
			sleep_spin(now_us() + sample_ms * 1000LL);
		}
		apply_level(1); /* floor rest */
		sleep_spin(now_us() + rest_ms * 1000LL);
	}
	/* stop path: quick fall then off */
	apply_level(3);
	sleep_spin(now_us() + 120 * 1000LL);
	apply_level(1);
	sleep_spin(now_us() + 150 * 1000LL);
	apply_level(0);
}
