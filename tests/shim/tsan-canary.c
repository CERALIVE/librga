// SPDX-License-Identifier: Apache-2.0
// Deliberate data race. Same job as asan-canary.c: prove the ThreadSanitizer
// runtime is intercepting, not merely linked. Until the concurrency reproducers
// land, this is the only thing that keeps the TSan leg of ci/sanitizers-steps.sh
// from being a green job that executed nothing.
#include <pthread.h>
#include <stdio.h>

static int shared; /* unsynchronised on purpose */

static void *bump(void *unused) {
	(void)unused;
	for (int i = 0; i < 10000; i++) shared++;
	return NULL;
}

int main(void) {
	pthread_t a, b;
	if (pthread_create(&a, NULL, bump, NULL) || pthread_create(&b, NULL, bump, NULL)) return 2;
	pthread_join(a, NULL);
	pthread_join(b, NULL);
	printf("NO TSAN REPORT: two threads raced on one int, final value %d\n", shared);
	return 0;
}
