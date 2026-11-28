/* effects.h — effect module API.
 * Adding an effect: write eff_<name>.c defining one effect_t, then add it to
 * the registry in effects.c. That's the whole integration surface.
 */
#ifndef RINGLIGHT_EFFECTS_H
#define RINGLIGHT_EFFECTS_H

typedef struct {
	const char *name; /* "chase" */
	const char *desc; /* one-line English description */
	void (*run)(void); /* blocking; poll ringlight_should_stop() */
} effect_t;

const effect_t *effect_find(const char *name);
void effects_list(void); /* print name+desc to stderr */

#endif
