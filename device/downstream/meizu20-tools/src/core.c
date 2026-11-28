/* core.c — i2c register access, pacing, boot state machine
 * Hardware map (round 135 calibration): dual SY7808 @0x63,
 * A = i2c master 98c000, B = 988000 (bus numbers drift; probe via of_node).
 * Registers: 0x01 enable (L1 b0 | L2 b1 | torch mode b3), 0x05 (L3 enable b7),
 * 0x06/07/08 torch current codes, 60 levels x 17.58mA, no auto-increment.
 * Lamp map (user-counted): 1=B L1, 2=A L3, 3=B L2, 4=A L1, 5=B L3, 6=A L2.
 */
#include "core.h"

#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/wait.h>

#define SLAVE 0x63
#define I2C_SLAVE 0x0703 /* from <linux/i2c-dev.h>; avoid header dependency */
#define BOOT_EXTRA_MS 10000LL /* keep animating 10s after graphical.target */

static const unsigned char SREG[3] = { 0x06, 0x07, 0x08 };
/* clockwise lamp -> (chip, sink); A = master 98c000 */
static const int RING[RING_N][2] = {
	{ 1, 0 }, /* lamp 1 = B L1 */
	{ 0, 2 }, /* lamp 2 = A L3 */
	{ 1, 1 }, /* lamp 3 = B L2 */
	{ 0, 0 }, /* lamp 4 = A L1 */
	{ 1, 2 }, /* lamp 5 = B L3 */
	{ 0, 1 }, /* lamp 6 = A L2 */
};

static int g_fd[2] = { -1, -1 };
static unsigned char g_cur[2][3] = { { 0xFF, 0xFF, 0xFF }, { 0xFF, 0xFF, 0xFF } };
/* cached enable bytes: 0x01 (b0=L1 b1=L2 b3=torch mode), 0x05 (b7=L3) */
static unsigned char g_en[2] = { 0x00, 0x00 };
static unsigned char g_en05[2] = { 0x00, 0x00 };

static volatile sig_atomic_t *g_stop_flag; /* points at main's flag */

static void w8raw(int chip, unsigned reg, unsigned val) {
	unsigned char b[2] = { (unsigned char)reg, (unsigned char)val };
	write(g_fd[chip], b, 2);
}

void ringlight_bind_stop(volatile sig_atomic_t *flag) { g_stop_flag = flag; }

long long now_us(void) {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (long long)ts.tv_sec * 1000000LL + ts.tv_nsec / 1000;
}
void sleep_hybrid(long long target) {
	long long r = target - now_us();
	if (r > 3000)
		usleep((useconds_t)(r - 2000));
	while (now_us() < target)
		;
}
void sleep_spin(long long target) {
	while (now_us() < target)
		;
}

static int find_bus(const char *master) {
	DIR *d = opendir("/sys/bus/i2c/devices");
	if (!d)
		return -1;
	char path[320], tgt[512], *p;
	int bus = -1;
	struct dirent *e;
	while ((e = readdir(d)) && bus < 0) {
		if (!strstr(e->d_name, "-0063"))
			continue;
		snprintf(path, sizeof path, "/sys/bus/i2c/devices/%s/of_node", e->d_name);
		ssize_t n = readlink(path, tgt, sizeof tgt - 1);
		if (n < 0)
			continue;
		tgt[n] = 0;
		if ((p = strstr(tgt, master)) && p[strlen(master)] == '/')
			bus = atoi(e->d_name);
	}
	closedir(d);
	return bus;
}

int buses_open(void) {
	int a = -1, b = -1;
	for (int t = 0; t < 20 && (a < 0 || b < 0); t++) { /* wait for i2c up */
		if (a < 0)
			a = find_bus("i2c@98c000");
		if (b < 0)
			b = find_bus("i2c@988000");
		if (a < 0 || b < 0)
			usleep(500000);
	}
	if (a < 0 || b < 0) {
		fprintf(stderr, "ringlight: SY7808 buses not found\n");
		return -1;
	}
	char dev[32];
	snprintf(dev, sizeof dev, "/dev/i2c-%d", a);
	if ((g_fd[0] = open(dev, O_RDWR)) < 0 || ioctl(g_fd[0], I2C_SLAVE, SLAVE) < 0) {
		perror(dev);
		return -1;
	}
	snprintf(dev, sizeof dev, "/dev/i2c-%d", b);
	if ((g_fd[1] = open(dev, O_RDWR)) < 0 || ioctl(g_fd[1], I2C_SLAVE, SLAVE) < 0) {
		perror(dev);
		return -1;
	}
	return 0;
}
void buses_close(void) {
	for (int i = 0; i < 2; i++)
		if (g_fd[i] >= 0)
			close(g_fd[i]);
}

/* level semantics (round 135+2 arbitration): register value V = (V+1)×17.58mA —
 * there is NO "zero current" register; OFF = disable the sink's enable bit.
 * level 0 = sink disabled; level L≥1 = register L-1 (L1 = 17.58mA minimum). */
static void sink_set(int chip, int ri, unsigned level) {
	/* current register: only meaningful when enabled */
	unsigned char reg = level ? (unsigned char)(level - 1) : 0;
	if (level && g_cur[chip][ri] != reg) {
		unsigned char b[2] = { SREG[ri], reg };
		if (write(g_fd[chip], b, 2) == 2)
			g_cur[chip][ri] = reg;
	}
	/* enable bit: the real on/off switch */
	unsigned char bit, *cache, eaddr;
	if (ri == 2) {
		bit = 0x80; cache = &g_en05[chip]; eaddr = 0x05;
	} else {
		bit = (unsigned char)(1u << ri); cache = &g_en[chip]; eaddr = 0x01;
	}
	unsigned char nv = level ? (*cache | bit) : (unsigned char)(*cache & ~bit);
	if (nv != *cache) {
		w8raw(chip, eaddr, nv);
		*cache = nv;
	}
}
void sinks_apply(const int codes[RING_N]) {
	for (int i = 0; i < RING_N; i++)
		sink_set(RING[i][0], RING[i][1], (unsigned)codes[i]);
}
void sinks_set_all(unsigned level) {
	for (int c = 0; c < 2; c++)
		for (int r = 0; r < 3; r++)
			sink_set(c, r, level);
}
void sinks_apply_all(unsigned reg) { /* raw register force (frame-cost probe only) */
	unsigned char b[2];
	for (int c = 0; c < 2; c++) {
		for (int r = 0; r < 3; r++) {
			b[0] = SREG[r];
			b[1] = (unsigned char)reg;
			if (write(g_fd[c], b, 2) == 2)
				g_cur[c][r] = (unsigned char)reg;
		}
	}
}
void sinks_clear(void) {
	int z[RING_N] = { 0 };
	sinks_apply(z);
}
void enables_set(int on) { /* mass: torch mode + all sink bits, or full off */
	unsigned char a = on ? 0x0B : 0x00, l = on ? 0x80 : 0x00;
	w8raw(0, 0x01, a); w8raw(0, 0x05, l);
	w8raw(1, 0x01, a); w8raw(1, 0x05, l);
	g_en[0] = g_en[1] = a;
	g_en05[0] = g_en05[1] = l;
	g_cur[0][0] = g_cur[0][1] = g_cur[0][2] = 0xFF;
	g_cur[1][0] = g_cur[1][1] = g_cur[1][2] = 0xFF;
}
void torch_gate(int on) { /* mode-bit PWM gate: currents/sink bits untouched */
	unsigned char nv = on ? (unsigned char)(g_en[0] | 0x08)
	                      : (unsigned char)(g_en[0] & ~0x08);
	if (nv == g_en[0])
		return;
	w8raw(0, 0x01, nv);
	w8raw(1, 0x01, nv);
	g_en[0] = g_en[1] = nv;
}

int ringlight_fd(int chip) {
	return g_fd[chip];
}
int ring_chip_of(int lamp) {
	return RING[lamp][0];
}
int ring_sink_of(int lamp) {
	return RING[lamp][1];
}

/* ---- boot state machine ---- */
static int g_boot = 0;
static long long g_cap = 0, g_deadline = 0, g_next_check = 0;

static int graphical_active(void) {
	pid_t p = fork();
	if (p < 0)
		return 0;
	if (p == 0) {
		execl("/usr/bin/systemctl", "systemctl", "is-active", "--quiet",
			"graphical.target", (char *)0);
		_exit(127);
	}
	int st = 0;
	waitpid(p, &st, 0);
	return WIFEXITED(st) && WEXITSTATUS(st) == 0;
}
void boot_arm(long long cap_ms) {
	g_boot = 1;
	g_cap = now_us() + cap_ms * 1000LL;
}
int ringlight_should_stop(void) {
	if (g_stop_flag && *g_stop_flag)
		return 1;
	if (!g_boot)
		return 0;
	long long now = now_us();
	if (now >= g_cap)
		return 1;
	if (g_deadline && now >= g_deadline)
		return 1;
	if (!g_deadline && now >= g_next_check) {
		g_next_check = now + 700000LL;
		if (graphical_active())
			g_deadline = now + BOOT_EXTRA_MS * 1000LL;
	}
	return 0;
}
