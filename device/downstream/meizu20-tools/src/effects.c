/* effects.c — the registry. New effects: define eff_<name> in its own file,
 * add one line here. */
#include "effects.h"

#include <stdio.h>
#include <string.h>

extern const effect_t eff_chase;
extern const effect_t eff_flow;
extern const effect_t eff_breath;
extern const effect_t eff_alternate;
extern const effect_t eff_breath2;
extern const effect_t eff_random;

const effect_t *const effects[] = {
	&eff_chase,
	&eff_flow,
	&eff_breath,
	&eff_alternate,
	&eff_breath2,
	&eff_random,
	0,
};

const effect_t *effect_find(const char *name) {
	for (int i = 0; effects[i]; i++)
		if (!strcmp(name, effects[i]->name))
			return effects[i];
	return 0;
}
void effects_list(void) {
	for (int i = 0; effects[i]; i++)
		fprintf(stderr, "  %-8s %s\n", effects[i]->name, effects[i]->desc);
}
