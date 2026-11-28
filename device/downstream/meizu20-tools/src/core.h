/* core.h — ringlight hardware/pacing/boot core (shared by all effects) */
#ifndef RINGLIGHT_CORE_H
#define RINGLIGHT_CORE_H

#include <signal.h>

#define RING_N 6 /* lamps on the ring, clockwise */

void ringlight_bind_stop(volatile sig_atomic_t *flag); /* main calls once */

long long now_us(void);
void sleep_hybrid(long long target); /* coarse sleep + spin tail (step modes) */
void sleep_spin(long long target);   /* pure spin (dither modes, exact cadence) */

int buses_open(void); /* detect + open both SY7808 i2c clients, 0 = ok */
void buses_close(void);

void sinks_apply(const int codes[RING_N]); /* per-lamp current codes, prev-skip */
void sinks_set_all(unsigned v);            /* uniform code, prev-skip */
void sinks_apply_all(unsigned v);          /* uniform code, forced write (measurement) */
void sinks_clear(void);
void enables_set(int on); /* all sinks enabled (torch mode + L1/L2/L3 bits) */
void torch_gate(int on);  /* mode-bit gate: all lamps on/off, 2 writes (PWM edge) */

void boot_arm(long long cap_ms);  /* enable boot state machine (cap + graphical) */
int ringlight_should_stop(void);  /* signals | boot cap | graphical+10s deadline */

int ringlight_fd(int chip); /* raw i2c fd (breath PWM workers; bypasses caches) */
int ring_chip_of(int lamp); /* ring lamp index -> chip (0=A,1=B) */
int ring_sink_of(int lamp); /* ring lamp index -> sink (0=L1,1=L2,2=L3) */

#endif
