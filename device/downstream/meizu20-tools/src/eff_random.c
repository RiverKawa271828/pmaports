/* eff_random.c — router-style random blinks (user round 135+2): each round
 * picks 1..6 lamps at random; every picked lamp blinks 1..3 times with
 * random on/off windows at level 1 (17.6mA floor); when all lamps are done
 * the round ends and a new random round begins.
 */
#include "core.h"
#include "effects.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static void run(void);

const effect_t eff_random = { "random", "router-style random blinks, 1-6 lamps per round", run };

#define TICK_MS 50
#define MAX_BLINKS 3

static void run(void) {
	const int level = 1;
	fprintf(stderr, "ringlight: random level=%d tick=%dms\n", level, TICK_MS);
	srand((unsigned)time(0));

	int c[RING_N];
	while (!ringlight_should_stop()) {
		/* --- new round --- */
		int picked[RING_N] = { 0 };
		int count = 1 + rand() % RING_N;
		for (int i = 0; i < count; i++) { /* sample without replacement */
			int lamp;
			do {
				lamp = rand() % RING_N;
			} while (picked[lamp]);
			picked[lamp] = 1;
		}
		/* per-lamp blink schedule: alternating on/off windows in ticks */
		int state[RING_N] = { 0 };      /* -1 = not picked/resting */
		int remain[RING_N] = { 0 };     /* ticks left in current window */
		int blinks_left[RING_N] = { 0 };
		int total_ticks = 0;
		for (int i = 0; i < RING_N; i++) {
			if (!picked[i]) {
				state[i] = -1;
				continue;
			}
			blinks_left[i] = 1 + rand() % MAX_BLINKS;
			/* stagger: start UNLIT, first blink after a random 0-800ms delay
			 * (all-lit-at-once was a 6x17.6mA burst at every round start) */
			state[i] = 0;
			remain[i] = rand() % (800 / TICK_MS);
			int len = remain[i];
			for (int b = blinks_left[i] - 1; b > 0; b--) {
				len += (40 + rand() % 120) / TICK_MS; /* off gap */
				len += (40 + rand() % 120) / TICK_MS; /* next on */
			}
			len += (800 / TICK_MS) + 20 / TICK_MS + 1; /* include start delay */
			if (len > total_ticks)
				total_ticks = len;
		}
		/* --- run the round --- */
		for (int t = 0; t < total_ticks && !ringlight_should_stop(); t++) {
			for (int i = 0; i < RING_N; i++) {
				if (state[i] < 0)
					continue;
				if (--remain[i] <= 0) {
					if (state[i] == 1) {
						state[i] = 0; /* lit window ended */
						if (--blinks_left[i] > 0) {
							remain[i] = (40 + rand() % 120) / TICK_MS;
						} else {
							state[i] = -1; /* this lamp is done */
						}
					} else {
						state[i] = 1; /* gap ended, blink again */
						remain[i] = (40 + rand() % 120) / TICK_MS;
					}
				}
				c[i] = (state[i] == 1) ? level : 0;
			}
			sinks_apply(c);
			sleep_spin(now_us() + TICK_MS * 1000LL);
		}
		sinks_clear();
		/* short breather between rounds */
		for (int t = 0; t < 4 && !ringlight_should_stop(); t++)
			sleep_spin(now_us() + 100 * 1000LL);
	}
}
