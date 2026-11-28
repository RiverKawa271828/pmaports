/* main.c — CLI, config, lifecycle.
 * All user-facing text is English (user request 2026-11-28). Package name:
 * ringlight (user delegated naming; rename = touch Makefile + unit + config).
 */
#include "core.h"
#include "effects.h"

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CFG_PATH "/etc/default/ringlight"
#define BOOT_CAP_MS 300000LL /* hard cap: even if graphical never comes */

static volatile sig_atomic_t g_stop = 0;
static void on_sig(int s) { (void)s; g_stop = 1; }

static void usage(void) {
	fprintf(stderr,
		"usage: ringlight <command>\n"
		"  chase | flow | breath | alternate | breath2 | random\n                           run an effect (Ctrl-C to stop)\n"
		"  boot                     boot animation: effect from config ('off' =\n"
		"                           dark); stops 10s after graphical.target\n"
		"  mode <chase|flow|breath> select the boot effect\n"
		"  off                      lights off (manual kill switch)\n"
		"effects:\n");
	effects_list();
}

static void read_boot_mode(char *out, size_t n) {
	/* mode sources: user-writable /var/lib/ringlight/mode (the GUI writes it)
	 * first, then /etc/default/ringlight (root CLI); bare word or MODE= both OK */
	const char *paths[2] = { "/var/lib/ringlight/mode", CFG_PATH };
	snprintf(out, n, "flow"); /* default */
	for (int i = 0; i < 2; i++) {
		FILE *f = fopen(paths[i], "r");
		if (!f)
			continue;
		char line[128];
		if (fgets(line, sizeof line, f)) {
			char *p = strstr(line, "MODE=");
			p = p ? p + 5 : line;
			for (char *q = p; *q; q++)
				if (*q == '\n' || *q == '\r' || *q == ' ' || *q == '\t')
					*q = 0;
			if (p[0]) {
				snprintf(out, n, "%s", p);
				fclose(f);
				return;
			}
		}
		fclose(f);
	}
}

int main(int argc, char **argv) {
	if (argc < 2) {
		usage();
		return 2;
	}
	if (!strcmp(argv[1], "mode") && argc > 2) {
		if (!effect_find(argv[2])) {
			fprintf(stderr, "ringlight: unknown effect '%s'\n", argv[2]);
			return 2;
		}
		FILE *f = fopen(CFG_PATH, "w");
		if (!f) {
			perror(CFG_PATH);
			return 1;
		}
		fprintf(f, "MODE=%s\n", argv[2]);
		fclose(f);
		printf("boot mode set: %s\n", argv[2]);
		return 0;
	}
	if (!strcmp(argv[1], "off")) { /* manual kill switch */
		if (buses_open() == 0) {
			sinks_clear();
			enables_set(0);
			printf("lamps off\n");
		}
		return 0;
	}

	char mode[64];
	if (!strcmp(argv[1], "boot")) {
		read_boot_mode(mode, sizeof mode);
		if (!strcmp(mode, "off")) /* master off: exit before touching i2c */
			return 0;
		boot_arm(BOOT_CAP_MS);
		fprintf(stderr, "ringlight: boot, effect=%s, cap=%llds\n", mode,
			BOOT_CAP_MS / 1000);
	} else {
		snprintf(mode, sizeof mode, "%s", argv[1]);
	}
	const effect_t *eff = effect_find(mode);
	if (!eff) {
		fprintf(stderr, "ringlight: unknown effect '%s'\n\n", mode);
		usage();
		return 2;
	}

	if (buses_open() != 0)
		return 1;
	ringlight_bind_stop(&g_stop);
	signal(SIGINT, on_sig);
	signal(SIGTERM, on_sig);
	signal(SIGHUP, on_sig);
	signal(SIGQUIT, on_sig);

	sinks_clear();
	enables_set(1);
	eff->run();
	sinks_clear();
	enables_set(0);
	buses_close();
	fprintf(stderr, "ringlight: exit clean\n");
	return 0;
}
