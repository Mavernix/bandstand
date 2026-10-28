# build with meson: meson setup build && meson compile -C build

project(
    'bandstand',
    'cpp',
    version: '0.1.0',
    license: 'GPL-3.0-or-later',
    default_options: [
        'cpp_std=c++17',
        'warning_level=2',
        'buildtype=debugoptimized',
    ],
)

qt = import('qt6')
qt_modules = dependency('qt6', modules: ['Core', 'Gui', 'Qml', 'Quick'])

# shared by the app and the tests
logic_sources = [
    'track.cpp', 'card.cpp', 'track-model.cpp', 'card-model.cpp',
    'playlist-list.cpp', 'library.cpp', 'play-queue.cpp',
]
program_sources = ['main.cpp', 'music-client.cpp', 'content-page.cpp']
program_headers = ['music-client.hpp', 'content-page.hpp']
logic_headers = ['track-model.hpp', 'card-model.hpp', 'playlist-list.hpp', 'library.hpp', 'play-queue.hpp']

moc_sources = qt.compile_moc(
    headers: program_headers + logic_headers,
    dependencies: qt_modules,
)

executable(
    'bandstand',
    [program_sources, logic_sources, moc_sources],
    dependencies: [qt_modules],
    # qml and the helper are loaded straight from the source tree, so qml edits need no rebuild
    cpp_args: [
        '-DQML_DIRECTORY="' + meson.current_source_dir() / 'qml' + '"',
        '-DHELPER_DIRECTORY="' + meson.current_source_dir() / 'helper' + '"',
    ],
)

qt_test = dependency('qt6', modules: ['Core', 'Test'], required: false)
if qt_test.found()
    queue_moc = qt.compile_moc(
        headers: ['tests/check-queue.hpp'] + logic_headers,
        dependencies: qt_test,
    )
    check_queue = executable(
        'check-queue',
        ['tests/check-queue.cpp', logic_sources, queue_moc],
        dependencies: [qt_test],
    )
    test('queue', check_queue)

    library_moc = qt.compile_moc(
        headers: ['tests/check-library.hpp'] + logic_headers,
        dependencies: qt_test,
    )
    check_library = executable(
        'check-library',
        ['tests/check-library.cpp', logic_sources, library_moc],
        dependencies: [qt_test],
    )
    test('library', check_library)
endif
