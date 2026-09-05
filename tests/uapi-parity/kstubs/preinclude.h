/*
 * Forced preinclude (-include) for compiling the island multi_rga header
 * UNMODIFIED in userspace.
 *
 * The island header is a kernel driver header, not a sanitised UAPI header: it
 * #includes <linux/mutex.h> and <linux/scatterlist.h>, and it defines
 * kernel-side structures next to the ones userspace actually passes through
 * ioctl(). We must compile the exact sha-verified bytes, so we cannot patch it;
 * instead we build a compile ENVIRONMENT that supplies only what the header
 * uses but does not itself include.
 *
 * THE RULE THIS FILE LIVES UNDER
 * -----------------------------
 * Nothing here may define, or influence the layout of, any structure the parity
 * gate compares. Only C primitives, the kernel's short integer aliases, and
 * OPAQUE forward declarations (which have no size and no members, so they can
 * only ever appear behind a pointer). check-stubs.sh enforces this mechanically:
 * it fails if this file declares any field-bearing struct, any struct named in
 * the compared UAPI list, or any RGA_* macro.
 *
 * If the island ever puts a genuinely kernel-only type INSIDE a UAPI struct
 * (say a struct mutex by value rather than by pointer), this file will not
 * rescue it --- the opaque declaration has no size, so the build FAILS loudly.
 * That failure is the correct outcome: it is a driver UAPI defect to raise on
 * the island track, not something for this gate to paper over.
 */

#ifndef LIBRGA_UAPI_PARITY_PREINCLUDE_H
#define LIBRGA_UAPI_PARITY_PREINCLUDE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <linux/types.h>
#include <linux/ioctl.h>

/*
 * The kernel's short integer aliases. The island header uses these directly
 * (e.g. `u8 src0_mmu_flag;`, `bool enable;`) without including the header that
 * defines them, because in-tree it gets them transitively.
 */
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;

/*
 * <linux/bits.h> in-tree. The island header uses BIT() for its request flags.
 * A macro, not a type: it cannot affect any struct layout.
 */
#ifndef BIT
#define BIT(nr) (1UL << (nr))
#endif

/*
 * Opaque forward declarations for the kernel objects the island header names.
 * Incomplete by design: usable only through a pointer, so they contribute
 * pointer-sized members at most and can never silently stand in for a real
 * kernel layout.
 */
struct mutex;
struct sg_table;
struct scatterlist;
struct dma_buf;
struct dma_buf_attachment;
struct device;
struct file;
struct page;

#endif /* LIBRGA_UAPI_PARITY_PREINCLUDE_H */
