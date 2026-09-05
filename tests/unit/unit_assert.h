/* SPDX-License-Identifier: Apache-2.0 */
#ifndef LIBRGA_TESTS_UNIT_ASSERT_H
#define LIBRGA_TESTS_UNIT_ASSERT_H

#include <cstdio>
#include <cstdlib>
#include <cmath>

/*
 * Minimal counting assertion harness. Every failure names its subject, so a
 * regression report identifies the table row (e.g. "NV16 bpp") rather than a
 * line number. Nothing here stops at the first failure: one run reports the
 * whole damaged surface.
 */

static int unit_checks;
static int unit_failures;
static int unit_section_base;
static const char *unit_section;

static inline void unit_close_section(void)
{
    if (!unit_section)
        return;
    printf("-- %s: %d assertions --\n", unit_section, unit_checks - unit_section_base);
    unit_section = NULL;
}

static inline void unit_begin(const char *group)
{
    unit_close_section();
    unit_section = group;
    unit_section_base = unit_checks;
    printf("== %s ==\n", group);
}

static inline void unit_fail(const char *subject, const char *detail)
{
    ++unit_failures;
    printf("FAIL %s: %s\n", subject, detail);
}

static inline void unit_pass(const char *subject)
{
    (void)subject;
}

static inline void unit_eq_int(const char *subject, long expected, long actual)
{
    ++unit_checks;
    if (expected == actual) { unit_pass(subject); return; }
    char detail[160];
    snprintf(detail, sizeof(detail), "expected %ld, got %ld", expected, actual);
    unit_fail(subject, detail);
}

static inline void unit_eq_hex(const char *subject, unsigned long expected, unsigned long actual)
{
    ++unit_checks;
    if (expected == actual) { unit_pass(subject); return; }
    char detail[160];
    snprintf(detail, sizeof(detail), "expected 0x%lx, got 0x%lx", expected, actual);
    unit_fail(subject, detail);
}

/*
 * bpp values are exact small binaries (0.25/0.5/1/1.5/2/2.5/3/3.75/4) in the
 * production table, so an exact float comparison is intentional. A tolerance
 * would silently accept a table that drifted by a fraction of a bit.
 */
static inline void unit_eq_bpp(const char *subject, float expected, float actual)
{
    ++unit_checks;
    if (expected == actual) { unit_pass(subject); return; }
    char detail[160];
    snprintf(detail, sizeof(detail), "expected %.5f, got %.5f", (double)expected, (double)actual);
    unit_fail(subject, detail);
}

static inline int unit_report(const char *suite)
{
    unit_close_section();
    printf("%s: %d assertions, %d failures\n", suite, unit_checks, unit_failures);
    return unit_failures ? 1 : 0;
}

#endif /* LIBRGA_TESTS_UNIT_ASSERT_H */
