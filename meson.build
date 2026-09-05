project(
    'librga',
    'cpp',
    version : '2.1.0',
    meson_version : '>=0.47.0',
    default_options : ['warning_level=3', 'cpp_std=c++14']
)

pkgconfig = import('pkgconfig')

libthreads_dep = dependency('threads')

add_project_arguments('-DLINUX=1', language : 'cpp')

librga_srcs = [
    'core/utils/android_utils/src/android_utils.cpp',
    'core/utils/drm_utils/src/drm_utils.cpp',
    'core/utils/utils.cpp',
    'core/GrallocOps.cpp',
    'core/NormalRgaApi.cpp',
	'core/NormalRga.cpp',
	'core/RgaUtils.cpp',
	'core/RockchipRga.cpp',
	'core/RgaApi.cpp',
	'core/rga_sync.cpp',
    'im2d_api/src/im2d_log.cpp',
    'im2d_api/src/im2d_debugger.cpp',
    'im2d_api/src/im2d_impl.cpp',
	'im2d_api/src/im2d.cpp',
]

incdir = include_directories('include', 'im2d_api', 'core/hardware', 'core/utils', 'core/3rdparty/libdrm/include/drm')

librga = shared_library(
    'rga',
    librga_srcs,
    dependencies : [libthreads_dep],
	include_directories : incdir,
    version : meson.project_version(),
    cpp_args : ['-w'],
    install : true,
)

librga_so = librga
librga = static_library(
    'rga',
    librga_srcs,
    dependencies : [libthreads_dep],
        include_directories : incdir,
    cpp_args : ['-w'],
    install : true,
)

install_headers(
    'include/rga.h',
    'include/drmrga.h',
    'include/GrallocOps.h',
    'include/RockchipRga.h',
    'include/RgaMutex.h',
	'include/RgaSingleton.h',
	'include/RgaUtils.h',
	'include/RgaApi.h',
	'im2d_api/im2d.h',
	'im2d_api/im2d.hpp',
    'im2d_api/im2d_type.h',
    'im2d_api/im2d_version.h',
    'im2d_api/im2d_buffer.h',
    'im2d_api/im2d_common.h',
    'im2d_api/im2d_single.h',
    'im2d_api/im2d_task.h',
    'im2d_api/im2d_mpi.h',
    'im2d_api/im2d_expand.h',
    subdir : 'rga',
)

pkgconfig.generate(
    libraries : librga,
    filebase : 'librga',
    name : 'librga',
    version : meson.project_version(),
    description : 'Userspace interface to Rockchip RGA 2D accelerator',
    extra_cflags : ['-I${includedir}/rga'],
)

librga_demo_option = get_option('librga_demo')
if librga_demo_option != 'false'
    demo_src = [
        'samples/utils/utils.cpp',
        'samples/utils/allocator/dma_alloc.cpp',
        'samples/utils/allocator/drm_alloc.cpp',
		'samples/im2d_api_demo/rgaImDemo.cpp',
		'samples/im2d_api_demo/args.cpp',
	]
    demo_incdir = include_directories(
        'include',
        'im2d_api',
        'samples/utils',
        'samples/utils/allocator/include',
        'utils/3rdparty/libdrm/include',
        'utils/3rdparty/libdrm/include/libdrm'
    )
    librga_dep = dependency('librga')
    executable(
            'rgaImDemo',
            demo_src,
            include_directories : demo_incdir,
            dependencies : librga_dep,
            cpp_args : ['-Wno-pedantic'],
            install : true,
    )
endif
# --- test fragments (wired by coordinator) ---
# >>> fragment: uapi-parity.build
# --- uapi-parity: assert librga's ioctl ABI still matches the island driver ---
#
# Fragment contract: this file is appended to the project's top-level
# meson.build, so every path below is relative to the project root.
#
# What it wires up:
#   * a custom target that fetches the pinned island driver header over HTTPS
#     and refuses it unless the bytes hash to tests/uapi-parity/island-pin.env
#   * two freestanding C emitters, one per side, that print {kind, name, value}
#     tables of ioctl numbers, struct sizes and member offsets
#   * the uapi-parity-stubs test --- the anti-cheat gate on the compile
#     environment that lets the kernel header build in userspace
#   * the uapi-parity test --- the comparator, which also regenerates
#     docs/UAPI-PARITY.md so a stale doc shows up as a git diff
#
# The emitters are linked -static so qemu-aarch64 needs no sysroot, and they
# pull in nothing from librga itself: each is a pure statement of what its own
# headers say the ABI is.

add_languages('c', required : true)

uapi_parity_python = find_program('python3', required : true)

uapi_parity_fetch = find_program(
    'tests/uapi-parity/fetch-island-header.sh',
    required : true,
)

# Fail-closed: the script verifies the SHA-256 before it writes @OUTPUT@, so a
# substituted or truncated header can never reach the compiler.
uapi_parity_island_header = custom_target(
    'island-rga-h',
    output : 'island-rga.h',
    command : [uapi_parity_fetch, '@OUTPUT@'],
    build_by_default : false,
)

# '.' resolves to BOTH the source root and the build root, which is how
# island_side.c finds the fetched header without naming a build path.
uapi_parity_island_inc = include_directories(
    '.',
    'tests/uapi-parity/kstubs',
)

uapi_parity_librga_inc = include_directories(
    'include',
    'core/hardware',
)

uapi_parity_island = executable(
    'uapi-parity-island-side',
    ['tests/uapi-parity/island_side.c', uapi_parity_island_header],
    include_directories : uapi_parity_island_inc,
    c_args : [
        '-std=gnu11',
        '-Wall',
        '-Wextra',
        # The island header is a kernel header. The forced preinclude supplies
        # the primitives and opaque declarations it uses but does not include;
        # tests/uapi-parity/check-stubs.sh proves it supplies nothing else.
        '-include',
        join_paths(
            meson.source_root(),
            'tests/uapi-parity/kstubs/preinclude.h',
        ),
    ],
    link_args : ['-static'],
    build_by_default : false,
    install : false,
)

uapi_parity_librga = executable(
    'uapi-parity-librga-side',
    ['tests/uapi-parity/librga_side.c'],
    include_directories : uapi_parity_librga_inc,
    c_args : ['-std=gnu11', '-Wall', '-Wextra'],
    link_args : ['-static'],
    build_by_default : false,
    install : false,
)

test(
    'uapi-parity-stubs',
    find_program('tests/uapi-parity/check-stubs.sh', required : true),
    suite : ['uapi'],
    timeout : 60,
)

test('uapi-parity',
    uapi_parity_python,
    args : [
        files('tests/uapi-parity/compare.py'),
        '--island-exe', uapi_parity_island,
        '--librga-exe', uapi_parity_librga,
        '--pin-env', files('tests/uapi-parity/island-pin.env'),
        '--emit-doc', join_paths(meson.source_root(), 'docs/UAPI-PARITY.md'),
    ],
    depends : [uapi_parity_island, uapi_parity_librga],
    suite : ['uapi'],
    timeout : 300,
)
# >>> fragment: goldens.build
# Append verbatim to the root meson.build; no demo dependency.
add_languages('c')
golden_dl = meson.get_compiler('c').find_library('dl')
golden_librga = static_library('rga-golden-host', librga_srcs,
    include_directories : incdir,
    dependencies : [libthreads_dep],
    cpp_args : ['-w', '-ftrivial-auto-var-init=zero'],
    install : false)
fake_rga = shared_library('fake_rga', 'tests/shim/fake_rga.c',
    include_directories : incdir,
    dependencies : [libthreads_dep, golden_dl],
    c_args : ['-std=gnu11', '-Wall', '-Wextra', '-Werror', '-Wno-pedantic'],
    install : false)
golden_cases = executable('golden-cases', 'tests/golden/cases.c',
    include_directories : incdir,
    link_with : golden_librga,
    dependencies : [libthreads_dep, golden_dl],
    c_args : ['-std=gnu11', '-Wall', '-Wextra', '-Werror', '-Wno-pedantic'],
    install : false)
fake_rga_env = environment()
fake_rga_env.set('LD_PRELOAD', fake_rga.full_path())
golden_shell = find_program('sh')
shim_contract = executable('shim-contract', 'tests/shim/contract.c',
    include_directories : incdir,
    dependencies : [golden_dl],
    c_args : ['-std=gnu11', '-Wall', '-Wextra', '-Werror', '-Wno-pedantic'],
    install : false)
test('shim-contract', shim_contract, env : fake_rga_env, depends : fake_rga)
foreach golden_case : ['G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7', 'G8']
    test('goldens', golden_shell,
        args : [files('tests/golden/run.sh'), golden_cases.full_path(),
                fake_rga.full_path(), meson.current_source_dir() / 'tests/golden', golden_case],
        depends : [fake_rga, golden_cases],
        timeout : 30)
endforeach
# >>> fragment: unit.build
# Append verbatim to the root meson.build, AFTER tests/meson-fragments/goldens.build.
# This fragment deliberately declares no library targets of its own: it reuses
# golden_librga (built with -ftrivial-auto-var-init=zero, which the CSC request
# inspection below needs), fake_rga and golden_dl from that fragment. Declaring
# them again would collide on the target names.
unit_warnings = ['-Wall', '-Wextra', '-Werror', '-Wno-pedantic']
unit_incdir = include_directories('im2d_api/src')
unit_pure = executable('unit-pure', 'tests/unit/unit_pure.cpp',
    include_directories : [incdir, unit_incdir],
    link_with : golden_librga,
    dependencies : [libthreads_dep, golden_dl],
    cpp_args : unit_warnings,
    install : false)
# No env: this group must prove it needs no /dev/rga, and it refuses to run if
# the shim is preloaded anyway.
test('unit-pure', unit_pure, timeout : 30)
unit_session = executable('unit-session', 'tests/unit/unit_session.cpp',
    include_directories : [incdir, unit_incdir],
    link_with : golden_librga,
    dependencies : [libthreads_dep, golden_dl],
    cpp_args : unit_warnings,
    install : false)
unit_session_env = environment()
unit_session_env.set('LD_PRELOAD', fake_rga.full_path())
unit_session_env.set('FAKE_RGA_LOG', meson.current_build_dir() / 'unit-session-interposed.log')
test('unit-session', unit_session, env : unit_session_env, depends : fake_rga, timeout : 30)
# >>> fragment: board.build
add_languages('c')
board_cc = meson.get_compiler('c')
board_math = board_cc.find_library('m')
board_dl = board_cc.find_library('dl')
board_cargs = ['-std=gnu11', '-Wall', '-Wextra', '-Werror', '-Wno-pedantic']
board_oracle = static_library('board-oracle', 'tests/oracle/oracle.c',
    c_args : board_cargs, install : false)
oracle_test = executable('oracle-test', 'tests/oracle/test-oracle.c',
    link_with : board_oracle, dependencies : board_math, c_args : board_cargs, install : false)
test('board-oracle', oracle_test)
executable('probe-version', 'tests/board/probe-version.c',
    include_directories : incdir, link_with : librga_so,
    c_args : board_cargs, install : false)
executable('rga-convert-bench', 'tests/board/rga-convert-bench.c',
    include_directories : incdir, link_with : [librga_so, board_oracle],
    dependencies : [board_math, board_dl], c_args : board_cargs, install : false)
board_timing = shared_library('rga_timing', 'tests/shim/fake_rga.c',
    include_directories : incdir, dependencies : [board_dl, libthreads_dep],
    c_args : board_cargs + ['-DFORWARD_TIMING'], install : false)
timing_contract = executable('timing-contract', 'tests/shim/timing-contract.c',
    dependencies : board_dl, export_dynamic : true, c_args : board_cargs, install : false)
timing_env = environment()
timing_env.set('LD_PRELOAD', board_timing.full_path())
test('board-timing', timing_contract, env : timing_env, depends : board_timing)
